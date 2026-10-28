terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
  backend "s3" {
    bucket = "cdis-state-ac433568766270-gen3"
    key    = "jq-commons"
    region = "us-east-1"
  }
}

module "gen3_commons" {
  source = "git::https://github.com/uc-cdis/gen3-terraform.git//tf_files/aws/commons?ref=feat/csoc"

  vpc_name = var.vpc_name # Example required variable, modify as needed
  users_policy = "test"
  csoc_managed = false
  deploy_jupyter=false
  es_linked_role=false
  enable_vpc_endpoints=false
}
