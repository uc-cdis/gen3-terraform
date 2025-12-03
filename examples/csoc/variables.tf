variable "account_number" {
  type        = string
  description = "AWS account number where resources will be created. If not set, falls back to data.aws_caller_identity.current.account_id."
  default     = null
}

variable "aws_region" {
  description = "The AWS region where the resources will be created in"
  type        = string
}

variable "kubernetes_namespace" {
  description = "The namespace your gen3 deployment will use"
  type        = string
  default     = "default"
}

variable "availability_zones" {
  description = "The availability zones where the resources will be created in. There should be 3 availability zones"
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) == 3
    error_message = "Exactly 3 availability zones must be provided."
  }
}

variable "hostname" {
  description = "The hostname for your gen3 deployment"
  type        = string
}

variable "es_linked_role" {
  description = "Whether to create elasticsearch service linked role. Set to false if already created in account"
  type        = bool
  default     = false
}

variable "revproxy_arn" {
  description = "The ARN of the certificate in ACM"
  type        = string
}

variable "create_gitops_infra" {
  description = "Whether or not to create users/buckets needed for useryaml gitops management"
  type        = bool
  default     = true
}

variable "user_yaml_bucket_name" {
  description = "The name of the S3 bucket where the user.yaml file will be stored"
  type        = string
}

variable "default_tags" {
  description = "Default tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}

variable "ssh_key" {
  type        = string
  description = "Name of the SSH key used to access the nodes in the EKS cluster."
  default     = ""
}

# Cognito Variables
variable "deploy_cognito" {
  description = "Whether to deploy Cognito resources"
  type        = bool
  default     = false
}

variable "user_pool_name" {
  description = "The name of the Cognito user pool"
  type        = string
  default     = null
}

variable "app_client_name" {
  description = "The name of the Cognito app client"
  type        = string
  default     = null
}

variable "domain_prefix" {
  description = "The domain prefix for Cognito hosted UI"
  type        = string
  default     = null
}

variable "callback_urls" {
  description = "List of allowed callback URLs for Cognito"
  type        = list(string)
  default     = []
}

variable "logout_urls" {
  description = "List of allowed logout URLs for Cognito"
  type        = list(string)
  default     = []
}

variable "allowed_oauth_flows" {
  description = "List of allowed OAuth flows"
  type        = list(string)
  default     = ["code"]
}

variable "allowed_oauth_scopes" {
  description = "List of allowed OAuth scopes"
  type        = list(string)
  default     = ["email", "openid", "phone", "profile"]
}

variable "supported_identity_providers" {
  description = "List of supported identity providers"
  type        = list(string)
  default     = ["COGNITO"]
}






# EKS Module Variables

variable "vpc_name" {}

variable "vpc_id" {
  default = ""
}

variable "csoc_managed" {
  default = false
}

variable "ec2_keyname" {
  default = ""
}

variable "instance_type" {
  default = "t3.large"
}

variable "jupyter_instance_type"{
  default = "t3.large"
}

variable "workflow_instance_type"{
  default = "t3.2xlarge"
}

variable "peering_cidr" {
  default = "10.128.0.0/20"
}

variable "secondary_cidr_block" {
  default = ""
}

variable "users_policy" {
  default = "test-commons"
}

variable "worker_drive_size" {
  default = 30
}

variable "eks_version" {
  default = "1.25"
}

variable "workers_subnet_size" {
  default = 24
}

variable "kernel" {
  default = "N/A"
}

variable "bootstrap_script" {
  default = "bootstrap.sh"
}

variable "jupyter_bootstrap_script" {
  default =  "bootstrap.sh"
}

variable "jupyter_worker_drive_size" {
  default = 30
}

variable "workflow_bootstrap_script" {
  default =  "bootstrap.sh"
}

variable "workflow_worker_drive_size" {
  default = 30
}

variable "cidrs_to_route_to_gw" {
  default = []
}

variable "proxy_name" {
  default = " HTTP Proxy"
}

variable "jupyter_asg_desired_capacity" {
  default = 0
}

variable "jupyter_asg_max_size" {
  default = 10
}

variable "jupyter_asg_min_size" {
  default = 0
}

variable "workflow_asg_desired_capacity" {
  default = 0
}

variable "workflow_asg_max_size" {
  default = 50
}

variable "workflow_asg_min_size" {
  default = 0
}

variable "iam-serviceaccount" {
  default = false
}

variable "oidc_eks_thumbprint" {
  description = "Thumbprint for the AWS OIDC identity provider"
  default     = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"] #pragma: allowlist secret
}

variable "domain_test" {
  description = "Domain for the lambda function to check for the proxy"
  default     = "www.google.com"
}

variable "ha_squid" {
  description = "Is HA squid deployed?"
  default     = true
}

variable "deploy_workflow" {
  description = "Deploy workflow nodepool?"
  default     = false
}

variable "secondary_availability_zones" {
  description = "AZ to be used by EKS nodes in the secondary subnet"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
}

variable "deploy_jupyter" {
  description = "Deploy workflow nodepool?"
  default     = false
}

variable "dual_proxy" {
  description = "Single instance and HA"
  default     = false
}

variable "single_az_for_jupyter" {
  description = "Jupyter notebooks on a single AZ"
  default     = false
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  default     = "arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-topic"
}

variable "activation_id" {
  default = ""
}

variable "customer_id" {
  default = ""
}

variable "fips" {
  default = false
}

# the key that was used to encrypt the FIPS enabled AMI
# This is needed to ASG can decrypt the ami 
variable "fips_ami_kms" {
  default = "arn:aws:kms:us-east-1:707767160287:key/mrk-697897f040ef45b0aa3cebf38a916f99"
}

# This is the FIPS enabled AMI in cdistest account.
variable "fips_enabled_ami" {
  default = "ami-0de87e3680dcb13ec"
}

variable "use_asg" {
  default = false
} 

variable "use_karpenter" {
  default = false
}

variable "deploy_karpenter_in_k8s" {
  default = false
  description = "Allows you to enable the Karpenter Helm chart and associated resources without deploying the other parts of karpenter (i.e. the roles, permissions, and SQS queue)"
}

variable "karpenter_version" {
  default = "1.0.8"
}

variable "spot_linked_role" {
  default = false
}

variable "scale_in_protection" {
  description = "set scale-in protection on ASG"
  default     = false
}

variable "ci_run" {
  default = false
}

variable "eks_public_access" {
  default = "true"
}

variable "enable_vpc_endpoints" {
  default = false
}

variable "k8s_bootstrap_resources" {
  default = false
  description = "If set to true, creates resources for bootstrapping a kubernetes cluster (such as karpenter configs and helm releases)"
}

variable "ha_squid_single_instance" {
  description = "If true, deploy a single instance of squid in an autoscaling group"
  default     = false
}




# VPC Module Variables


# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  default = "amazon"
}

variable "vpc_cidr_block" {
  default = "172.24.16.0/20"
}

variable "vpc_flow_logs" {
  default = false
}

variable "vpc_flow_traffic" {
  default = "ALL"
}

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {
  default = "someone@uchicago.edu"
}

variable "csoc_account_id" {
  default = "433568766270"
}

variable "peering_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "organization_name" {
  description = "for tagging purposes"
  default     = "Basic Service"
}

variable "squid_image_search_criteria" {
  description = "Search criteria for squid AMI look up"
  default = "amzn2-ami-hvm-*-x86_64-gp2"
}

variable "squid_instance_drive_size" {
  description = "Volume size for the squid instance"
  default     = 30
}

variable "squid_instance_type" {
  description = "Instance type for HA squid instances"
  default     = "t3.medium"
}

variable "squid_bootstrap_script" {
  description = "Script to run on deployment for the HA squid instances"
  default     = "squid_running_on_docker.sh"
}

variable  "deploy_single_proxy" {
  description = "Single instance plus HA"
  default     = false
}

variable "squid_extra_vars" {
  description = "additional variables to pass along with the bootstrapscript"
  default     = ["squid_image=master"]
}

variable "branch" {
  description = "For testing purposes, when something else than the master"
  default     = "master"
}

variable "fence-bot_bucket_access_arns" {
  description = "When fence bot has to access another bucket that wasn't created by the VPC module"
  default     = []
}

variable "deploy_ha_squid" {
  description = "should you want to deploy HA-squid"
  default     = false
}

variable "squid_cluster_desired_capasity" {
  description = "If ha squid is enabled and you want to set your own capasity"
  default     = 2
}

variable "squid_cluster_min_size" {
  description = "If ha squid is enabled and you want to set your own min size"
  default     = 1
}

variable "squid_cluster_max_size" {
  description = "If ha squid is enabled and you want to set your own max size"
  default     = 3
}

variable "single_squid_instance_type" {
  description = "Single squid instance type"
  default     = "t2.micro"
}

variable "network_expansion" {
  description = "Let k8s wokers use /22 subnets per AZ"
  default     = false
}

variable "slack_webhook" {
  default = ""
}

variable "deploy_cloud_trail" {
  default = true
}

variable "send_logs_to_csoc" {
  default = true
}

variable "commons_log_retention" {
  description = "value in days for the cloudwatch log retention period"
  default = "3653"
}

variable "squid_image_ssm_parameter_name" {
  description = "If provided, use this SSM parameter to get the AMI ID at launch time instead of squid_image_search_criteria"
  default = "resolve:ssm:arn:aws:ssm:us-east-1:143731057154:parameter/gen3/squid-ami"
}
  
variable "force_delete_bucket" {
  description = "Force delete the data bucket"
  default     = false
}

variable "sqs_encryption_enabled" {
  description = "Enable server-side encryption for the SQS queue"
  type        = bool
  default     = true
}

variable "sqs_kms_key_id" {
  description = "KMS Key ID to use for server-side encryption. If not provided, the default AWS managed key will be used."
  type        = string
  default     = ""
}