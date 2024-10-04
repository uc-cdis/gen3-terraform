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

module "aws_waf" {
  source                            = "../modules/waf"
  count                             = var.deploy_waf ? 1 : 0
  vpc_name                          = var.vpc_name
  base_rules                        = var.base_rules
  additional_rules                  = var.additional_rules
}