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

resource "aws_kms_key" "central_backup_key" {
  description             = "KMS key for encrypting RDS backups from other accounts"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_backup_vault" "account_vaults" {
  for_each = var.account_ids
  
  name        = "rds-central-backup-vault-${each.value}"
  kms_key_arn = aws_kms_key.central_backup_key.arn
  
  tags = {
    Name      = "rds-central-backup-vault-${each.value}"
    AccountId = each.key
  }
}

resource "aws_backup_vault_policy" "account_vaults_policies" {
  for_each = var.account_ids

  backup_vault_name = aws_backup_vault.account_vaults[each.value].name
  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow",
        Action = "backup:CopyIntoBackupVault",
        Resource = "*",
        Principal = {
          AWS = [
            "arn:aws:iam::${each.value}:root"
          ]
        }
      }
    ]
  })
}