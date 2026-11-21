variable "account_ids" {
  description = "List of AWS account IDs to create backup vaults for"
  type        = set(string)
  validation {
    condition = alltrue([
      for account_id in var.account_ids : can(regex("^[0-9]{12}$", account_id))
    ])
    error_message = "Account IDs must be 12-digit strings."
  }
}
variable "snapshot_share_source_accounts" {
  description = "Accounts using the backup module's snapshot_share mode (typically accounts outside this account's AWS Organization). Their shared RDS snapshots are copied into this account and expired on the source's schedule."
  type        = set(string)
  default     = []
}

variable "freshness_alarm_accounts" {
  description = "Map of source account ID => max hours since its newest backup copy landed here. Covers both aws_backup copies and snapshot_share copies. Use ~30 for accounts with daily cross-account copies, ~200 for weekly."
  type        = map(number)
  default     = {}
}

variable "alert_email_addresses" {
  description = "Email addresses subscribed to central backup alerts."
  type        = list(string)
  default     = []
}

variable "alert_sns_topic_arn" {
  description = "Existing SNS topic for alerts. If empty, a topic named rds-central-backup-alerts is created."
  type        = string
  default     = ""
}
