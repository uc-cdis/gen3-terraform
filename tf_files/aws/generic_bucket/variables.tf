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

variable "aes_encryption" {
  default = false
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
  description = "Principal ARNs to grant policy_actions on the bucket. Empty means no bucket policy is created."
  type        = list(string)
  default     = []

  # This is the root module Terragrunt binds TF_VAR_policy_role_arn to, and
  # environment variables are parsed against the declared type. While this was
  # untyped it was inferred as a string, so a list of ARNs arrived as one
  # literal "[\"arn:...\",\"arn:...\"]" principal and S3 rejected the resulting
  # policy with MalformedPolicy: Invalid principal in policy.
}

variable "policy_actions" {
  type    = list(string)
  default = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
}
