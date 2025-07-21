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

variable "region" {
  description = "The AWS region in which backups should live"
  type        = string
  default     = "us-east-1"
}
