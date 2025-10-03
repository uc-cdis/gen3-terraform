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
