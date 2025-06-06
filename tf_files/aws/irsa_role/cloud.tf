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

locals {
  default_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Sid    = ""
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/${var.eks_cluster_oidc_arn}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.eks_cluster_oidc_arn}:sub" = "system:serviceaccount:${var.kubernetes_namespace}:${var.kubernetes_service_account}"
            "${var.eks_cluster_oidc_arn}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}


module "iam_role" {
  source                         = "../modules/iam-role"
  role_name                      = var.role_name
  role_assume_role_policy        = var.role_assume_role_policy != "" ? var.role_assume_role_policy : local.default_trust_policy
  role_tags                      = var.role_tags
  role_force_detach_policies     = var.role_force_detach_policies
  role_description               = var.role_description
}

module "iam_role_policy" {
  source                         = "../modules/iam-policy"
  policy_name                    = var.policy_name
  policy_path                    = var.policy_path
  policy_description             = var.policy_description
  policy_json                    = var.policy_json
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = module.iam_role.role_id
  policy_arn = module.iam_role_policy.arn
}