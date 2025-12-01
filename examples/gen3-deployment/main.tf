provider "aws" {

  region = local.aws_region

  default_tags {
    tags = local.default_tags
  }
}

data "aws_caller_identity" "current" {}

terraform {
  backend "s3" {
    # The bucket to store the Terraform state file in.
    bucket = "elise-tftest" # Update to represent your environment
    # The location of the Terraform state file within the bucket. Notice the bucket has to exist beforehand.
    key = "gen3-commons/terraform.tfstate" # Update to represent your environment    
    encrypt = "true"
    # The region where the S3 bucket is located.
    region = "us-east-1"
  }
}

locals {
  # Core settings
  vpc_name             = var.vpc_name
  account_number       = coalesce(var.account_number, data.aws_caller_identity.current.account_id)
  aws_region           = var.aws_region
  kubernetes_namespace = var.kubernetes_namespace
  availability_zones   = var.availability_zones
  hostname             = var.hostname

  # Feature toggles / flags
  es_linked_role       = var.es_linked_role
  create_gitops_infra  = var.create_gitops_infra

  # Certificates / buckets / keys
  revproxy_arn         = var.revproxy_arn
  user_yaml_bucket_name = var.user_yaml_bucket_name
  ssh_key              = var.ssh_key

  # Tags: use provided tags if non-empty, otherwise default to Environment = vpc_name
  default_tags = length(var.default_tags) > 0 ? var.default_tags : {
    Environment = local.vpc_name
  }


  ### Cognito setup
  deploy_cognito = true
  user_pool_name  = "${local.vpc_name}-pool"
  app_client_name = "${local.vpc_name}-client"
  domain_prefix = "${local.vpc_name}-auth"
  callback_urls = [
    "https://${local.hostname}/",
    "https://${local.hostname}/login/",
    "https://${local.hostname}/login/cognito/login/",
    "https://${local.hostname}/user/",
    "https://${local.hostname}/user/login/cognito/",
    "https://${local.hostname}/user/login/cognito/login/",
  ]
  logout_urls = [
    "https://${local.hostname}/",
  ]
  allowed_oauth_flows  = ["code"]
  allowed_oauth_scopes = ["email", "openid", "phone", "profile"]
  supported_identity_providers = ["COGNITO"]
}

module "commons" {
  source = "git::github.com/uc-cdis/gen3-terraform.git//tf_files/aws/commons?ref=521e908e4a11f87c54c2389f792f5622ec429793"

  vpc_name                       = local.vpc_name
  vpc_cidr_block                 = "10.10.0.0/20"
  aws_region                     = local.aws_region
  hostname                       = local.hostname
  kube_ssh_key                   = local.ssh_key
  ami_account_id                 = "amazon"
  squid_image_search_criteria    = "amzn2-ami-hvm-*-x86_64-gp2"
  ha-squid_instance_drive_size   = 30
  ha_squid_single_instance       = true
  deploy_ha_squid                = true
  deploy_sheepdog_db             = false
  deploy_fence_db                = false
  deploy_indexd_db               = false
  network_expansion              = true
  users_policy                   = "dev"
  availability_zones             = local.availability_zones
  es_version                     = "7.10"
  es_linked_role                 = local.es_linked_role
  deploy_aurora                  = true
  deploy_rds                     = false
  use_asg                        = false
  use_karpenter                  = true
  deploy_karpenter_in_k8s        = true
  send_logs_to_csoc              = false
  secrets_manager_enabled        = true
  force_delete_bucket            = true
  enable_vpc_endpoints           = false
  cluster_engine_version         = "13"
}

module "gen3" {
  source = "git::github.com/uc-cdis/gen3-terraform.git//tf_files/gen3?ref=521e908e4a11f87c54c2389f792f5622ec429793"
  vpc_name                 = local.vpc_name
  aurora_username          = module.commons.aurora_cluster_master_username
  aurora_password          = module.commons.aurora_cluster_master_password
  aurora_hostname          = module.commons.aurora_cluster_writer_endpoint
  dictionary_url           = "https://s3.amazonaws.com/dictionary-artifacts/datadictionary/develop/schema.json"
  es_endpoint              = module.commons.es_endpoint
  hostname                 = local.hostname
  cluster_endpoint         = module.commons.eks_cluster_endpoint
  cluster_ca_cert          = module.commons.eks_cluster_ca_cert
  cluster_name             = module.commons.eks_cluster_name
  oidc_provider_arn        = module.commons.eks_oidc_arn
  fence_access_key         = module.commons.fence-bot_user_id
  fence_secret_key         = module.commons.fence-bot_user_secret
  upload_bucket            = module.commons.data-bucket_name
  revproxy_arn             = local.revproxy_arn
  useryaml_s3_path         = "s3://${local.user_yaml_bucket_name}/dev/user.yaml"
  deploy_external_secrets  = true
  deploy_gen3              = false
  create_dbs               = false
  cognito_discovery_url    = "https://${aws_cognito_user_pool.cognito_pool[0].endpoint}/.well-known/openid-configuration"
  cognito_client_id        = aws_cognito_user_pool_client.cognito_client[0].id
  cognito_client_secret    = aws_cognito_user_pool_client.cognito_client[0].client_secret

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }

  depends_on = [
    module.commons,
  ]
}


resource "aws_iam_user" "gitops_user" {
  count = local.create_gitops_infra ? 1 : 0
  name  = "gitops-user"
}

resource "aws_iam_user_policy" "gitops_s3_policy" {
  count = local.create_gitops_infra ? 1 : 0
  name  = "gitops-user-s3-access"
  user  = aws_iam_user.gitops_user[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${local.user_yaml_bucket_name}"
      },
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${local.user_yaml_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_access_key" "gitops_key" {
  count = local.create_gitops_infra ? 1 : 0
  user  = aws_iam_user.gitops_user[0].name
}

resource "aws_s3_bucket" "users_bucket" {
  count  = local.create_gitops_infra ? 1 : 0
  bucket = local.user_yaml_bucket_name
  force_destroy = true
  tags = {
    Name        = "user-yaml-bucket"
    Environment = local.vpc_name
  }
}
