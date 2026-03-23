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
    bucket = "pcdc-test-pcdc-developers-playground-973342646972" # Update to represent your environment
    # The location of the Terraform state file within the bucket. Notice the bucket has to exist beforehand.
    key = "gen3-terraform/terraform.tfstate" # Update to represent your environment    
    encrypt = "true"
    # The region where the S3 bucket is located.
    region = "us-east-2"
  }
}

locals {
  # This will be the name of the VPC, and will be used to identify most resources created within the module
  vpc_name                      = "pcdc-test"
  # The account number where the resources will be created in. This should be populated automatically through the AWS user/role you are using to run this module.
  account_number                = data.aws_caller_identity.current.account_id
  # The AWS region where the resources will be created in
  aws_region                    = "us-east-2"  
  # The namespace your gen3 deployment will use. Default is good for first time deployments.
  ## If you want another deployment in the same cluster, copy paste the gen3 module block, create a new namespace local variable or manually update the namespace within the second instance of the module.
  kubernetes_namespace          = "default"
  # The availability zones where the resources will be created in. There should be 3 availability zones
  ## You can run aws ec2 describe-availability-zones --region <region> to get the list of availability zones in your region.
  availability_zones            = ["us-east-2a", "us-east-2b", "us-east-2c"] # ex. ["us-east-1a", "us-east-1c", "us-east-1d"]
  # The hostname for your gen3 deployment. If you are creating another instance of the gen3 module set the hostname in it accordingly
  hostname                      = "portal-test.org"
  # Service linked roles can only be created once per account. If you see an error that it is already created, set this to false.
  es_linked_role                = true
  # The arn of the certificate in ACM
  revproxy_arn                  = "arn:aws:acm:us-east-1:009732147623:certificate/8f00318a-90dd-4601-9059-244274cedd08"
  # Whether or not to create users/buckets needed for useryaml gitops management.
  create_gitops_infra           = true
  # The name of the S3 bucket where the user.yaml file will be stored. Notice this will be created by terraform, so you don't need to create it beforehand.
  user_yaml_bucket_name = "pcdc-test-user-yaml"
  # Your ssh key name to access the nodes in the EKS cluster
  ssh_key                = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDP/kacKPy1OK2zDUk+1WEcZC7NiWoCPz8EczceisDdQif0dNP5YECkzxH+Aj80fYqxcEiIO61yn6rMJoOS2u7l9Bb2H4UQzUCwTPvAKtjrKNuOvXc3QK/Kb9PdD0Hc1HYJU4yQd8dXGCbfqY3PERBQaE+wfFgfz8vGhAIB+ggwsA7pekgicUJekCQ+amyVE2B26cTS4CVhzQB8kGSWKaU+k/LU6l2EVeLksa5abutErXONU6r8ly2clA/bbrjQZwFw34rl0K6RgBuxE/ktwMLNHJtMdVdCQqCbZiLIeLIvPkz7HtUvX7zdft0x4JP6cN7Ojbso2nPRI1n0cAZJhh0R/iMTl0uoDvlZ6JpIlCMFhp5YgtP8bK/w6FGnSOnYV8kCdAByfsn4kyvzS0CS1yLF93AEIgdGQv8a0ORJrWLPfLlbm9wOSQwhdwGTUMWjswNzZCE7AN4mT6uOzltj0sBzGvCqj7JHhM7MRfoag96oaYrdL1lpc9shKO/OZuOe3ATGl0clrhjDxeyRKmYDcyse0lSvGfXtB1Go0puEqEIy/Po3UjD5cZrpKkyPR02SsIg3dFE8WzVCsnYYohXHHvDDksmuwxHzw+3nPf/tI3VWbO+rzPmYJdDHy01fcQnJqzSEjUjWq0GiZFYX5nssDG7VO/bQcWJ2doA1xi132cngUw== ubuntu@ip-10-0-0-14"
  # Set any tags you want to apply to all resources created by this module.
  default_tags = {
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
  source = "./../../modules/pcdc-commons"
  vpc_name                       = local.vpc_name
  vpc_cidr_block                 = "10.10.0.0/20"
  aws_region                     = local.aws_region
  hostname                       = local.hostname
  kube_ssh_key                   = local.ssh_key
  ami_account_id                 = "amazon"
  squid_image_search_criteria    = "amzn2-ami-hvm-*-x86_64-gp2"
  ha-squid_instance_drive_size   = 30
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
  deploy_es                      = false
  deploy_es_role                 = false
}

module "gen3" {
  source = "./../../modules/pcdc-gen3"
  vpc_name                 = local.vpc_name
  aurora_username          = module.commons.aurora_cluster_master_username
  aurora_password          = module.commons.aurora_cluster_master_password
  aurora_hostname          = module.commons.aurora_cluster_writer_endpoint
  dictionary_url           = "https://s3.amazonaws.com/dictionary-artifacts/datadictionary/develop/schema.json"
  es_endpoint              = module.commons.es_endpoint != null ? module.commons.es_endpoint : ""
  hostname                 = local.hostname
  cluster_endpoint         = module.commons.eks_cluster_endpoint
  cluster_ca_cert          = module.commons.eks_cluster_ca_cert
  cluster_name             = module.commons.eks_cluster_name
  oidc_provider_arn        = module.commons.eks_oidc_arn
  fence_access_key         = module.commons.fence-bot_user_id
  fence_secret_key         = module.commons.fence-bot_user_secret
  upload_bucket            = module.commons.data-bucket_name
  amanuensis_access_key    = module.commons.amanuensis-bot_user_id
  amanuensis_secret_key    = module.commons.amanuensis-bot_user_secret
  data_release_bucket      = module.commons.data-release-bucket_name
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