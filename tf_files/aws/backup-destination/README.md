# TL;DR

Central backup account for Gen3 RDS / Aurora backups. Deploy it once, in the account that should hold a copy of every source account's backups. It creates:

* one AWS Backup vault per source account in `account_ids`, for `aws_backup`-mode copies
* an hourly collector Lambda that copies snapshots shared by `snapshot_share_source_accounts` and deletes them on the source's retention schedule
* a `Gen3Backup/HoursSinceLastCopy` metric and an alarm per account in `freshness_alarm_accounts`
* an SNS topic for alerts

Apply this before the source accounts (`../backup`).

## 1. QuickStart

```hcl
inputs = {
  account_ids                    = ["222222222222"]                      # aws_backup-mode source accounts
  snapshot_share_source_accounts = ["333333333333"]                      # snapshot_share-mode source accounts
  freshness_alarm_accounts       = { "222222222222" = 30, "333333333333" = 30 } # max hours between copies
  alert_email_addresses          = ["platform-team@example.org"]
}
```

Full guide: [docs/rds-backups-setup.md](../../../docs/rds-backups-setup.md).

## 2. Variables

| Name | Default | Description |
|---|---|---|
| `account_ids` | (required) | Source accounts that copy here with AWS Backup. Each gets `rds-central-backup-vault-<account>`. |
| `snapshot_share_source_accounts` | `[]` | Source accounts using `snapshot_share` mode. |
| `freshness_alarm_accounts` | `{}` | Map of account ID → maximum hours since the last copy (30 for daily backups, 200 for weekly-only). |
| `alert_email_addresses` | `[]` | Emails subscribed to alerts. |
| `alert_sns_topic_arn` | `""` | Use an existing SNS topic instead of creating `rds-central-backup-alerts`. |

Shared copies are stored as manual RDS snapshots and count toward the **manual DB cluster snapshots** quota (default 100 per region). Raise it before adding many `snapshot_share` accounts.
