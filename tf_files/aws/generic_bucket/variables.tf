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
  default     = ""
}

variable "kms_key_id" {
  description = "The KMS key to use for the bucket"
  default     = ""
}

variable "public_access_block" {
  default = true
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
  default = false
}

variable "bucket_lifecycle_configuration" {
  default = ""
}

variable "policy_role_arn" {
  default = ""
}

variable "policy_actions" {
  type    = list(string)
  default = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
}
