provider "aws" {
  region = local.aws_region

  default_tags {
    tags = local.default_tags
  }
}

# Alias used by old state / csoc bits
provider "aws" {
  alias  = "csoc"
  region = local.aws_region

  # You can copy the same tags or leave them out
  default_tags {
    tags = local.default_tags
  }
}

data "aws_caller_identity" "current" {}

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
}


module "eks" {
  source = "git::github.com/uc-cdis/gen3-terraform.git//tf_files/aws/modules/eks?ref=f345a784df4bddb1a81911351a9ec78dad83a7ca"
  providers = {
    aws      = aws       # default account
    aws.csoc = aws.csoc  # satisfy aws.csoc in state/module
  }
  depends_on              = [module.vpc]
  vpc_name                         = var.vpc_name
  vpc_id                           = var.vpc_id
  ec2_keyname                      = var.ec2_keyname
  instance_type                    = var.instance_type
  peering_cidr                     = var.peering_cidr
  secondary_cidr_block             = var.secondary_cidr_block
  users_policy                     = var.users_policy
  worker_drive_size                = var.worker_drive_size
  eks_version                      = var.eks_version
  jupyter_instance_type            = var.jupyter_instance_type
  deploy_jupyter                   = var.deploy_jupyter
  deploy_workflow                  = var.deploy_workflow
  workers_subnet_size              = var.workers_subnet_size
  bootstrap_script                 = var.bootstrap_script
  jupyter_bootstrap_script         = var.jupyter_bootstrap_script
  kernel                           = var.kernel
  jupyter_worker_drive_size        = var.jupyter_worker_drive_size
  cidrs_to_route_to_gw             = var.cidrs_to_route_to_gw
  organization_name                = var.organization_name
  peering_vpc_id                   = var.peering_vpc_id
  jupyter_asg_desired_capacity     = var.jupyter_asg_desired_capacity
  jupyter_asg_max_size             = var.jupyter_asg_max_size
  jupyter_asg_min_size             = var.jupyter_asg_min_size
  iam-serviceaccount               = var.iam-serviceaccount
  oidc_eks_thumbprint              = var.oidc_eks_thumbprint
  domain_test                      = var.domain_test
  ha_squid                         = var.ha_squid
  dual_proxy                       = var.dual_proxy
  single_az_for_jupyter            = var.single_az_for_jupyter
  sns_topic_arn                    = var.sns_topic_arn
  activation_id                    = var.activation_id
  customer_id                      = var.customer_id
  workflow_instance_type           = var.workflow_instance_type
  workflow_bootstrap_script        = var.workflow_bootstrap_script
  workflow_worker_drive_size       = var.workflow_worker_drive_size
  workflow_asg_desired_capacity    = var.workflow_asg_desired_capacity
  workflow_asg_max_size            = var.workflow_asg_max_size
  workflow_asg_min_size            = var.workflow_asg_min_size
  deploy_workflow                  = var.deploy_workflow
  fips                             = var.fips
  fips_ami_kms                     = var.fips_ami_kms
  fips_enabled_ami                 = var.fips_enabled_ami
  availability_zones               = var.availability_zones
  ci_run                           = var.ci_run
  use_asg                          = var.use_asg 
  use_karpenter                    = var.use_karpenter
  karpenter_version               = var.karpenter_version
  eks_public_access                = var.eks_public_access
  enable_vpc_endpoints             = var.enable_vpc_endpoints
  k8s_bootstrap_resources          = var.k8s_bootstrap_resources
}

module "vpc" {
  source = "git::github.com/uc-cdis/gen3-terraform.git//tf_files/aws/modules/vpc?ref=f345a784df4bddb1a81911351a9ec78dad83a7ca"
  providers = {
    aws      = aws       # default account
    aws.csoc = aws.csoc  # satisfy aws.csoc in state/module
  }
  ami_account_id                   = var.ami_account_id
  vpc_name                         = var.vpc_name
  vpc_cidr_block                   = var.vpc_cidr_block
  secondary_cidr_block             = var.secondary_cidr_block
  vpc_flow_logs                    = var.vpc_flow_logs
  vpc_flow_traffic                 = var.vpc_flow_traffic
  ssh_key_name                     = var.ssh_key_name
  csoc_account_id                  = var.csoc_account_id
  peering_cidr                     = var.peering_cidr
  peering_vpc_id                   = var.peering_vpc_id
  csoc_managed                     = var.csoc_managed
  organization_name                = var.organization_name
  availability_zones               = var.availability_zones
  squid_image_search_criteria      = var.squid_image_search_criteria
  squid_image_ssm_parameter_name = var.squid_image_ssm_parameter_name
  squid_instance_drive_size        = var.squid_instance_drive_size
  squid_instance_type              = var.squid_instance_type
  squid_bootstrap_script           = var.squid_bootstrap_script
  deploy_single_proxy              = var.deploy_single_proxy
  squid_extra_vars                 = var.squid_extra_vars
  branch                           = var.branch
  fence-bot_bucket_access_arns     = var.fence-bot_bucket_access_arns
  deploy_ha_squid                  = var.deploy_ha_squid
  squid_cluster_desired_capasity   = var.squid_cluster_desired_capasity
  squid_cluster_min_size           = var.squid_cluster_min_size
  squid_cluster_max_size           = var.squid_cluster_max_size
  single_squid_instance_type       = var.single_squid_instance_type
  network_expansion                = var.network_expansion
  activation_id                    = var.activation_id
  customer_id                      = var.customer_id
  slack_webhook                    = var.slack_webhook
  fips                             = var.fips
  deploy_cloud_trail               = var.deploy_cloud_trail
  send_logs_to_csoc                = var.send_logs_to_csoc
  commons_log_retention            = var.commons_log_retention
  force_delete_bucket              = var.force_delete_bucket
  ha_squid_single_instance         = var.ha_squid_single_instance
}

# add module for csoc deployment
# add module for cluster-level-resources


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