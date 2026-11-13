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

variable "encryption_enabled" {
  description = "Enable server-side encryption for the SQS queue"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS Key ID to use for server-side encryption. If not provided, the default AWS managed key will be used."
  type        = string
  default     = ""
}

variable "enable_key_rotation" {
  description = "Enable automatic rotation of the KMS key created for SNS/SQS encryption. Ignored when kms_key_id is provided."
  type        = bool
  default     = true
}
