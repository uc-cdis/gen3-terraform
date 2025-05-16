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

resource "aws_iam_role" "external-secrets-role" {
  name = "${var.commons_name}-external-secrets-sa"
  description = "Role for external-secrets service account for ${var.commons_name}"
  assume_role_policy = jsonencode({
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
        Sid = ""
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${var.account_id}:oidc-provider/${var.oidc_provider_id}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_id}:sub" = [
              "system:serviceaccount:${var.commons_name}:external-secrets"
            ]
            "${var.oidc_provider_id}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  path = "/gen3-service/"
}


resource "aws_iam_role_policy" "external-secrets-role-policy" {
  name = "external-secrets-role-policy"
  role = aws_iam_role.external-secrets-role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:ListSecrets",
          "secretsmanager:GetSecretValue"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}


resource "aws_iam_role_policy_attachment" "external-secrets-role-policy-attachment" {
  role = aws_iam_role.external-secrets-role.name
  policy_arn = aws_iam_role_policy.external-secrets-role-policy.arn
}