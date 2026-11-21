# TL;DR

Account-wide RDS / Aurora backups for a Gen3 source account (wraps `../modules/backup`). It creates:

* AWS Backup plans: daily (optional), weekly, monthly and yearly, for every RDS database in the account
* a local vault and a cross-region vault, each with its own KMS key
* an optional copy to a central backup account, by AWS Backup copy (same AWS Organization) or by RDS snapshot sharing (any org)
* EventBridge → SNS alerts for failed backup and copy jobs

Deploy `../backup-destination` in the central account first.

## 1. QuickStart

```hcl
inputs = {
  backup_destination_account = "111111111111" # central backup account; required for cross-account copies
  cross_account_mode         = "aws_backup"   # or "snapshot_share" if this account is in a different AWS Organization
  alert_email_addresses      = ["platform-team@example.org"]
}
```

Full guide: [docs/rds-backups-setup.md](../../../docs/rds-backups-setup.md). Design and restore procedures: [docs/rds-backups.md](../../../docs/rds-backups.md).

## 2. Variables

| Name | Default | Description |
|---|---|---|
| `backup_destination_account` | `null` | Central backup account ID. Cross-account copies are configured only when this is set. |
| `cross_account_backup` | `true` | Set to `false` to turn off cross-account copies even when a destination is set. |
| `cross_account_mode` | `"aws_backup"` | `aws_backup` (same AWS Organization only) or `snapshot_share` (any org). |
| `cross_account_min_retention_days` | `0` | Send only tiers retained at least this long cross-account: `30` for weekly and up, `365` for monthly and yearly. |
| `cross_region_destination` | `"us-west-1"` | Region of the second in-account vault. |
| `daily_backups_enabled` | `true` | Create the daily tier (7-day retention). |
| `excluded_dbs` | `[]` | ARNs of databases not to back up. |
| `alert_email_addresses` | `[]` | Emails subscribed to failure alerts. Each one must confirm the subscription. |
| `alert_sns_topic_arn` | `""` | Use an existing SNS topic instead of creating `rds-backup-alerts`. |
| `snapshot_share_staging_hours` | `72` | `snapshot_share` mode: hours before staging snapshots are deleted. |
| `snapshot_share_resource_types` | `["Aurora", "RDS"]` | `snapshot_share` mode: AWS Backup resource types to share. |
