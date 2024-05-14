terraform {
  backend "s3" {
    encrypt = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "s3_bucket" {
  source                         = "../modules/generic-bucket"
  bucket_name                    = var.bucket_name
  bucket_ownership               = var.bucket_ownership
  logging_bucket_name            = var.logging_bucket_name
  aes_encryption                 = var.aes_encryption
  kms_key_id                     = var.kms_key_id
  public_access_block            = var.public_access_block
  block_public_acls              = var.block_public_acls
  block_public_policy            = var.block_public_policy
  ignore_public_acls             = var.ignore_public_acls
  restrict_public_buckets        = var.restrict_public_buckets
  versioning                     = var.versioning
  bucket_lifecycle_configuration = var.bucket_lifecycle_configuration
  policy_role_arn                = var.policy_role_arn
  policy_actions                 = var.policy_actions
}
