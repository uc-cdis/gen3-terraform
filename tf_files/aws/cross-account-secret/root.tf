data "aws_caller_identity" "current" {}

terraform {
  backend "s3" {
    encrypt = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

# Create KMS key if not provided
resource "aws_kms_key" "secret_key" {
  count               = var.kms_key_arn == null ? 1 : 0
  description         = "KMS key for ${var.secret_name}"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow access from authorized accounts"
        Effect = "Allow"
        Principal = {
          AWS = [for account_id in var.authorized_account_ids : "arn:aws:iam::${account_id}:root"]
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "secret_key" {
  count         = var.kms_key_arn == null ? 1 : 0
  name          = "alias/${var.secret_name}"
  target_key_id = aws_kms_key.secret_key[0].key_id
}

# Determine which KMS key to use
locals {
  kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.secret_key[0].arn
}

# Create Secrets Manager secret
resource "aws_secretsmanager_secret" "secret" {
  name       = var.secret_name
  kms_key_id = local.kms_key_arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuthorizedAccounts"
        Effect = "Allow"
        Principal = {
          AWS = [for account_id in var.account_ids : "arn:aws:iam::${account_id}:root"]
        }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}