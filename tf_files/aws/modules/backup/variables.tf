variable "retention_period" {
  description = "The number of days to retain the backup"
  type        = number
  default     = 7
}

variable "excluded_dbs" {
  description = "A list of DB ARNs to be EXCLUDED from this backup"
  type        = list
  default     = []
}

variable "daily_backups_enabled" {
  description = "Whether or not the daily backups that are retained for 7 days are preserved"
  type        = bool
  default     = true
}

variable "cross_region_destination" {
  description = "The AWS region in which backups should live"
  type        = string
  default     = "us-west-1"
}

variable cross_account_backup {
  description = "Whether or not to enable cross-account backup. Must specify an account"
  type        = bool
  default     = true
}

variable backup_destination_account {
  description = "The aws account ID for the target backup account"
  type        = string
  default     = "433568766270"
}