# ===========================
# KMS keys and backup vaults
# ===========================

resource "aws_backup_vault" "rds_backup_vault" {
  name        = "rds-backup-vault"
  kms_key_arn = aws_kms_key.backup_key.arn
}

resource "aws_backup_vault" "cross_region_rds_backup_vault" {
  name        = "rds-cross-region-backup-vault-${var.cross_region_destination}"
  kms_key_arn = aws_kms_key.cross_region_rds_backup_key.arn
  region      = var.cross_region_destination
}

resource "aws_kms_key" "backup_key" {
  description             = "KMS key for encrypting RDS backups"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  region                  = "us-east-1"
}

resource "aws_kms_key_policy" "backup_key_external_account" {
  count = var.cross_account_backup ? 1: 0
  key_id = aws_kms_key.backup_key.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${var.backup_destination_account}:root",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/backup.amazonaws.com/AWSServiceRoleForBackup"
          ]
        }

        Resource = "*"
        Sid      = "Enable cross-account access to copy backups"
      },
    ]
  })
}

resource "aws_kms_key" "cross_region_rds_backup_key" {
  description             = "KMS key for encrypting RDS backups, in ${var.cross_region_destination}"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  region                  = var.cross_region_destination
}

# ==============
# Daily backups
# ==============

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

    copy_action {
      lifecycle {
        delete_after = 7 # Retain for 7 days
      }

      destination_vault_arn = aws_backup_vault.cross_region_rds_backup_vault.arn
    }

    dynamic "copy_action" {
      for_each = var.cross_account_backup ? [1]: []

      content {
        lifecycle {
          delete_after = 7 # Retain for 7 days
        }

        destination_vault_arn = "arn:aws:backup:us-east-1:${var.backup_destination_account}:backup-vault:rds-central-backup-vault-${data.aws_caller_identity.current.account_id}"
      }
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

# ===============
# Weekly backups
# ===============

resource "aws_backup_plan" "weekly" {
  name = "rds-weekly-backup-plan"

  rule {
    rule_name         = "weekly-backup-rule"
    target_vault_name = aws_backup_vault.rds_backup_vault.name
    schedule          = "cron(0 2 ? * 7 *)" # weekly at 2 AM UTC
    lifecycle {
      delete_after = 30 # Retain for 30 days
    }

    copy_action {
      lifecycle {
        delete_after = 30 # Retain for 30 days
      }

      destination_vault_arn = aws_backup_vault.cross_region_rds_backup_vault.arn
    }

    dynamic "copy_action" {
      for_each = var.cross_account_backup ? [1]: []

      content {
        lifecycle {
          delete_after = 30 # Retain for 30 days
        }

        destination_vault_arn = "arn:aws:backup:us-east-1:${var.backup_destination_account}:backup-vault:rds-central-backup-vault-${data.aws_caller_identity.current.account_id}"
      }
    }
  }
}

resource "aws_backup_selection" "weekly" {
  name          = "rds-weekly-backup-selection"
  iam_role_arn  = aws_iam_role.backup_role.arn
  plan_id = aws_backup_plan.weekly.id

  resources = [
    "arn:aws:rds:*"
  ]

  not_resources = var.excluded_dbs
}

# ================
# Monthly backups
# ================

resource "aws_backup_plan" "monthly" {
  name = "rds-monthly-backup-plan"

  rule {
    rule_name         = "monthly-backup-rule"
    target_vault_name = aws_backup_vault.rds_backup_vault.name
    schedule          = "cron(0 3 1 * ? *)" # Monthly on the 1st at 3 AM UTC
    lifecycle {
      delete_after = 365 # Retain for 365 days (1 year)
    }

    copy_action {
      lifecycle {
        delete_after = 365 # Retain for 365 days (1 year)
      }

      destination_vault_arn = aws_backup_vault.cross_region_rds_backup_vault.arn
    }

    dynamic "copy_action" {
      for_each = var.cross_account_backup ? [1]: []

      content {
        lifecycle {
          delete_after = 365 # Retain for 365 days (1 year)
        }

        destination_vault_arn = "arn:aws:backup:us-east-1:${var.backup_destination_account}:backup-vault:rds-central-backup-vault-${data.aws_caller_identity.current.account_id}"
      }
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

# ===============
# Yearly backups
# ===============

resource "aws_backup_plan" "yearly" {
  name = "rds-yearly-backup-plan"

  rule {
    rule_name         = "yearly-backup-rule"
    target_vault_name = aws_backup_vault.rds_backup_vault.name
    schedule          = "cron(0 4 1 1 ? *)" # Yearly on January 1st at 4 AM UTC
    lifecycle {
      delete_after = 2555 # Retain for 2555 days (7 years)
    }

    copy_action {
      lifecycle {
        delete_after = 2555 # Retain for 7 days
      }

      destination_vault_arn = aws_backup_vault.cross_region_rds_backup_vault.arn
    }

    dynamic "copy_action" {
      for_each = var.cross_account_backup ? [1]: []

      content {
        lifecycle {
          delete_after = 2555 # Retain for 2555 days (7 years)
        }

        destination_vault_arn = "arn:aws:backup:us-east-1:${var.backup_destination_account}:backup-vault:rds-central-backup-vault-${data.aws_caller_identity.current.account_id}"
      }
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

# ==============
# IAM and Auth
# ==============

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
