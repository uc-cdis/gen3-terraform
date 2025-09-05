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
  for_each = toset(var.account_ids)
  
  name        = "rds-central-backup-vault-${each.key[0]}"
  kms_key_arn = aws_kms_key.central_backup_key.arn
  
  tags = {
    Name      = "rds-central-backup-vault-${each.key[0]}"
    AccountId = each.key
  }
}