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

variable "block_public_acls" {
  default = true
}

variable "block_public_policy" {
  default = true
}

variable "ignore_public_acls" {
  default = true
}

variable "restrict_public_buckets" {
  default = true
}

variable "versioning" {
  default = true
}
