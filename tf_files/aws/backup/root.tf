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


module "backup" {
  source   = "../modules/backup"

  retention_period           = var.retention_period
  excluded_dbs               = var.excluded_dbs
  daily_backups_enabled      = var.daily_backups_enabled
  cross_region_destination   = var.cross_region_destination
  cross_account_backup       = var.cross_account_backup
  backup_destination_account = var.backup_destination_account
}