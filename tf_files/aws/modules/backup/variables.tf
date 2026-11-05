variable "retention_period" {
  description = "The number of days to retain the backup"
  type        = number
  default     = 7
}

variable "excluded_dbs" {
  description = "A list of DB ARNs to be EXCLUDED from this backup"
  type        = list(any)
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

variable "cross_account_backup" {
  description = "Whether or not to enable cross-account backup. Must specify an account"
  type        = bool
  default     = true
}

variable "backup_destination_account" {
  description = "The aws account ID for the target backup account"
  type        = string
  default     = "433568766270"
}
variable "cross_account_mode" {
  description = <<-EOT
    How backups reach the central backup account when cross_account_backup is true.
      "aws_backup"     - AWS Backup copy_action into the central vault. Only works while this
                         account and the destination are in the SAME AWS Organization.
      "snapshot_share" - Re-encrypt each recovery point with a shareable KMS key and share the
                         RDS snapshot with the destination account, which copies it and enforces
                         retention (see the backup-destination module). Works across orgs.
  EOT
  type        = string
  default     = "aws_backup"
  validation {
    condition     = contains(["aws_backup", "snapshot_share"], var.cross_account_mode)
    error_message = "cross_account_mode must be \"aws_backup\" or \"snapshot_share\"."
  }
}

variable "cross_account_min_retention_days" {
  description = "Only backup tiers retained at least this many days are sent cross-account (7=daily, 30=weekly, 365=monthly, 2555=yearly). Aurora cross-account copies are full copies, so raising this is the main cost lever."
  type        = number
  default     = 0
}

variable "snapshot_share_staging_hours" {
  description = "snapshot_share mode: hours to keep the re-encrypted staging snapshot in this account before deleting it. Must comfortably exceed the destination collector's schedule."
  type        = number
  default     = 72
}

variable "snapshot_share_resource_types" {
  description = "snapshot_share mode: AWS Backup resource types to share. Aurora/Neptune/DocumentDB are cluster snapshots, RDS is instance snapshots."
  type        = list(string)
  default     = ["Aurora", "RDS"]
}

variable "alert_email_addresses" {
  description = "Email addresses subscribed to backup failure alerts (each must confirm the SNS subscription)."
  type        = list(string)
  default     = []
}

variable "alert_sns_topic_arn" {
  description = "Existing SNS topic for backup alerts. If empty, a topic named rds-backup-alerts is created."
  type        = string
  default     = ""
}
