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

module "kms_key" {
  source              = "../modules/kms-key"
  account_ids         = var.account_ids
  action              = var.action
}
