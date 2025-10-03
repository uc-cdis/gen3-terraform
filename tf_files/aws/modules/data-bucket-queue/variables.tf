variable "bucket_name"{
  # this variable is required in config.tfvars
}

#
# AWS only allows one bucket notification config per bucket,
# so don't do this if the bucket already has a notification
# configured
#
variable "configure_bucket_notifications" {
  default = true
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