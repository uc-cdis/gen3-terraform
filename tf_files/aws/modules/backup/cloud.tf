resource "aws_backup_vault" "rds_backup_vault" {
  name        = "rds-backup-vault"
  kms_key_arn = aws_kms_key.backup_key.arn
}

resource "aws_kms_key" "backup_key" {
  description             = "KMS key for encrypting RDS backups"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_backup_plan" "rds_backup_plan" {
  name = "rds-backup-plan"

  rule {
    rule_name         = "rds-backup-rule"
    target_vault_name = aws_backup_vault.rds_backup_vault.name
    schedule          = "cron(0 2 * * ? *)"  # Run backup daily at 2:00 AM UTC

    lifecycle {
      delete_after = var.retention_period
    }
  }
}


resource "aws_iam_role" "backup_role" {
  name               = "rds-backup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backup_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role.name
}
