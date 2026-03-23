variable "vpc_name" {
  default = "Commons1"
}

variable "vpc_cidr_block" {
  default = "172.24.17.0/20"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "hostname" {
  default = "dev.bionimbus.org"
}

variable "kube_ssh_key" {
  default = "ssh-rsa createAKey"
}

variable "ami_account_id" {
  default = "137112412989"
}

variable "squid_image_search_criteria" {
  description = "Search criteria for squid AMI look up"
  default     = "amzn2-ami-hvm-*-x86_64-gp2"
}

variable "ha-squid_instance_drive_size" {
  description = "Volume size for HA squid instances"
  default     = 25
}

variable "deploy_ha_squid" {
  description = "Should you want to deploy HA-squid"
  default     = false
}

variable "deploy_sheepdog_db" {
  description = "Whether or not to deploy the database instance"
  default     = true
}

variable "deploy_fence_db" {
  description = "Whether or not to deploy the database instance"
  default     = true
}

variable "deploy_indexd_db" {
  description = "Whether or not to deploy the database instance"
  default     = true
}

variable "network_expansion" {
  description = "Let k8s workers be on a /22 subnet per AZ"
  default     = false
}

variable "users_policy" {}

variable "availability_zones" {
  description = "AZ to be used by EKS nodes"
  default     = ["us-east-1a", "us-east-1c", "us-east-1d"]
}

variable "es_version" {
  description = "What version to use when deploying ES"
  default     = "6.8"
}

variable "es_linked_role" {
  description = "Whether or no to deploy a linked roll for ES"
  default     = true
}

variable "cluster_engine_version" {
  description = "Aurora database engine version."
  type        = string
  default     = "13.7"
}

variable "deploy_aurora" {
  default = false
}

variable "deploy_rds" {
  default = true
}

variable "use_asg" {
  default = true
}

variable "use_karpenter" {
  default = false
}

variable "deploy_karpenter_in_k8s" {
  default = false
  description = "Allows you to enable the Karpenter Helm chart and associated resources without deploying the other parts of karpenter (i.e. the roles, permissions, and SQS queue)"
}

variable "send_logs_to_csoc" {
  default = true
}

variable "secrets_manager_enabled" {
  default = false
}

variable "force_delete_bucket" {
  description = "Force delete S3 buckets"
  type = bool
  default = false
}

variable "enable_vpc_endpoints" {
  default = true
}

variable "amanuensis-bot_bucket_access_arns" {
  description = "When amanuensis bot has to access another bucket that wasn't created by the VPC module"
  default     = []
}

variable "deploy_es_role" {
  default = false
}

variable "deploy_es" {
  default = true
}
