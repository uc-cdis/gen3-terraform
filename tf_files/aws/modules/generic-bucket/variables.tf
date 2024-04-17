variable "bucket_name" {}

variable "bucket_ownership" {
  default     = "BucketOwnerEnforced"
}

variable "logging_bucket_name" {
  type        = string
  default     = "logging"
}

variable "kms_key_id" {
  description = "The KMS key to use for the bucket"
}

variable "bucket_lifecycle_configuration" {
  default = ""
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

variable "policy_role_arn" {
  default = ""
}

variable "policy_actions" {
  type    = list(string)
  default = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
}