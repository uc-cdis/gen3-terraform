variable "sqs_name" {}

variable "slack_webhook"  {
  default = ""
}

variable "encrption_enabled" {
  description = "Enable server-side encryption for the SQS queue"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS Key ID to use for server-side encryption. If not provided, the default AWS managed key will be used."
  type        = string
  default     = ""
}