terraform {
  backend "s3" {
    encrypt = "true"
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    archive = {
      source = "hashicorp/archive"
    }
  }
}


module "backup" {
  source = "../modules/backup"

  retention_period         = var.retention_period
  excluded_dbs             = var.excluded_dbs
  daily_backups_enabled    = var.daily_backups_enabled
  cross_region_destination = var.cross_region_destination

  cross_account_backup             = var.cross_account_backup
  backup_destination_account       = var.backup_destination_account
  cross_account_mode               = var.cross_account_mode
  cross_account_min_retention_days = var.cross_account_min_retention_days
  snapshot_share_staging_hours     = var.snapshot_share_staging_hours
  snapshot_share_resource_types    = var.snapshot_share_resource_types
  alert_email_addresses            = var.alert_email_addresses
  alert_sns_topic_arn              = var.alert_sns_topic_arn
}