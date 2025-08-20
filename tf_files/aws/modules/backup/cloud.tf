resource "aws_backup_vault" "rds_backup_vault" {
  name        = "rds-backup-vault"
  kms_key_arn = aws_kms_key.backup_key.arn
  region      = var.region
}

resource "aws_kms_key" "backup_key" {
  description             = "KMS key for encrypting RDS backups"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_backup_plan" "daily" {
  name = "rds-daily-backup-plan"
  count = var.daily_backups_enabled ? 1 : 0

  rule {
    rule_name         = "daily-backup-rule"
    target_vault_name = aws_backup_vault.rds_backup_vault.name
    schedule          = "cron(0 2 * * ? *)" # Daily at 2 AM UTC
    lifecycle {
      delete_after = 7 # Retain for 7 days
    }
  }
}


resource "aws_backup_selection" "daily" {
  name          = "rds-daily-backup-selection"
  iam_role_arn  = aws_iam_role.backup_role.arn
  plan_id = aws_backup_plan.daily[0].id
  count = var.daily_backups_enabled ? 1 : 0

  resources = [
    "arn:aws:rds:*"
  ]

  not_resources = var.excluded_dbs
}


resource "aws_backup_plan" "monthly" {
  name = "rds-monthly-backup-plan"

  rule {
    rule_name         = "monthly-backup-rule"
    target_vault_name = aws_backup_vault.rds_backup_vault.name
    schedule          = "cron(0 3 1 * ? *)" # Monthly on the 1st at 3 AM UTC
    lifecycle {
      delete_after = 365 # Retain for 365 days (1 year)
    }
  }
}

resource "aws_backup_selection" "monthly" {
  name          = "rds-monthly-backup-selection"
  iam_role_arn  = aws_iam_role.backup_role.arn
  plan_id       = aws_backup_plan.monthly.id

  resources = [
    "arn:aws:rds:*"
  ]

  not_resources = var.excluded_dbs
}

resource "aws_backup_plan" "yearly" {
  name = "rds-yearly-backup-plan"

  rule {
    rule_name         = "yearly-backup-rule"
    target_vault_name = aws_backup_vault.rds_backup_vault.name
    schedule          = "cron(0 4 1 1 ? *)" # Yearly on January 1st at 4 AM UTC
    lifecycle {
      delete_after = 1825 # Retain for 1825 days (5 years)
    }
  }
}

resource "aws_backup_selection" "yearly" {
  name          = "rds-yearly-backup-selection"
  iam_role_arn  = aws_iam_role.backup_role.arn
  plan_id       = aws_backup_plan.yearly.id

  resources = [
    "arn:aws:rds:*"
  ]

  not_resources = var.excluded_dbs
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
