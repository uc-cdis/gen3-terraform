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


module "iam_role" {
  source                         = "../modules/iam-role"
  role_name                      = var.role_name
  role_assume_role_policy        = var.role_assume_role_policy
  role_tags                      = var.role_tags
  role_force_detach_policies     = var.role_force_detach_policies
  role_description               = var.role_description
}

module "iam_role_policy" {
  source                         = "../modules/iam-policy"
  policy_name                    = var.policy_name
  policy_path                    = var.policy_path
  policy_description             = var.policy_description
  policy_json                    = var.policy_path
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = module.iam_role.role_id
  policy_arn = module.iam_role_policy.arn
}
