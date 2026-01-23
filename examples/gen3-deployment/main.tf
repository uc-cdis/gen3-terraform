provider "aws" {

  region = local.aws_region

  default_tags {
    tags = local.default_tags
  }
}

data "aws_caller_identity" "current" {}



# Updated locals block using variables
locals {
  # This will be the name of the VPC, and will be used to identify most resources created within the module
  vpc_name                      = var.vpc_name
  # The account number where the resources will be created in. This should be populated automatically through the AWS user/role you are using to run this module.
  account_number                = data.aws_caller_identity.current.account_id
  # The AWS region where the resources will be created in
  aws_region                    = var.aws_region
  # The namespace your gen3 deployment will use. Default is good for first time deployments.
  ## If you want another deployment in the same cluster, copy paste the gen3 module block, create a new namespace local variable or manually update the namespace within the second instance of the module.
  kubernetes_namespace          = var.kubernetes_namespace
  # The availability zones where the resources will be created in. There should be 3 availability zones
  ## You can run aws ec2 describe-availability-zones --region <region> to get the list of availability zones in your region.
  availability_zones            = var.availability_zones
  # The hostname for your gen3 deployment. If you are creating another instance of the gen3 module set the hostname in it accordingly
  hostname                      = var.hostname
  # Service linked roles can only be created once per account. If you see an error that it is already created, set this to false.
  es_linked_role                = var.es_linked_role
  # The arn of the certificate in ACM
  revproxy_arn                  = var.revproxy_arn
  # Whether or not to create users/buckets needed for useryaml gitops management.
  create_gitops_infra           = var.create_gitops_infra
  # The name of the S3 bucket where the user.yaml file will be stored
  user_yaml_bucket_name         = var.user_yaml_bucket_name
  # Set any tags you want to apply to all resources created by this module.
  default_tags = merge(var.default_tags, {
    Environment = var.vpc_name
  })

  ### Cognito setup
  deploy_cognito = var.deploy_cognito
  user_pool_name = var.user_pool_name != null ? var.user_pool_name : "${var.vpc_name}-pool"
  app_client_name = var.app_client_name != null ? var.app_client_name : "${var.vpc_name}-client"
  domain_prefix = var.domain_prefix != null ? var.domain_prefix : "${var.vpc_name}-auth"
  callback_urls = length(var.callback_urls) > 0 ? var.callback_urls : [
    "https://${var.hostname}/",
    "https://${var.hostname}/login/",
    "https://${var.hostname}/login/cognito/login/",
    "https://${var.hostname}/user/",
    "https://${var.hostname}/user/login/cognito/",
  ]
  logout_urls = length(var.logout_urls) > 0 ? var.logout_urls : [
    "https://${var.hostname}/",
  ]
  allowed_oauth_flows  = var.allowed_oauth_flows
  allowed_oauth_scopes = var.allowed_oauth_scopes
  supported_identity_providers = var.supported_identity_providers
}

module "commons" {
  source = "git::github.com/uc-cdis/gen3-terraform.git//tf_files/aws/commons?ref=2fe47171d456c9537d79053397387acafaa5ecc3"

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
  source = "git::github.com/uc-cdis/gen3-terraform.git//tf_files/gen3?ref=2fe47171d456c9537d79053397387acafaa5ecc3"
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
