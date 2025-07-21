variable "vpc_name" {}

variable "environment" {}

variable "cloudwatchlogs_group" {}

variable "deploy_cloud_trail" {
  default = true
}

variable "force_delete_bucket" {
  description = "Force delete the bucket even if it contains objects"
  default     = false
}
