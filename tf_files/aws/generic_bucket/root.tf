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
  source              = "../modules/generic-bucket"
  bucket_name         = var.bucket_name
  bucket_ownership    = var.bucket_ownership
  cloudtrail_bucket   = var.cloudtrail_bucket
  logging_bucket_name = var.logging_bucket_name
  kms_key_id          = var.kms_key_id
}
