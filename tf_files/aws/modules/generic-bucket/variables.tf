variable "bucket_name" {}

variable "bucket_ownership" {
  default     = "BucketOwnerEnforced"
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
  default= ""
}

variable "bucket_lifecycle_configuration" {
  default = ""
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

variable "policy_role_arn" {
  description = "Principal(s) to grant policy_actions on the bucket. Accepts a single ARN or a list of ARNs. Empty means no bucket policy is created."
  type        = list(string)
  default     = []

  # Terragrunt passes inputs as TF_VAR_ environment variables, which are parsed
  # against the declared type. Without an explicit type this was inferred as a
  # string, so a list of ARNs arrived as one literal "[\"arn:...\",\"arn:...\"]"
  # principal and S3 rejected the policy with MalformedPolicy.
}

variable "policy_actions" {
  type    = list(string)
  default = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
}
