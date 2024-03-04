variable "bucket_name" {}

variable "bucket_ownership" {
  default     = "BucketOwnerEnforced"
}

variable "cloudtrail_bucket" {
  type        = bool
  default     = false
}

variable "logging_bucket_name" {
  type        = string
  default     = "logging"
}

variable "kms_key_id" {
  description = "The KMS key to use for the bucket"
  default     = ""
}
