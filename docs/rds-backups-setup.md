# Setting up RDS / Aurora backups for a Gen3 deployment

## TL;DR

1. Pick one AWS account to hold the central copy of every backup and deploy `tf_files/aws/backup-destination` there.
2. Deploy `tf_files/aws/backup` in every account that runs Gen3 databases, with `backup_destination_account` set to the central account.
3. Confirm the SNS email subscriptions, then check the next day that the first copies arrived.

The result is three copies of every database backup: one in the database's own region, one in a second region of the same account, and one in the central account. Alerts fire when a backup or copy fails, or when an account's copies stop arriving.

For how it works, the restore procedures and the AWS Organization move checklist, see [rds-backups.md](rds-backups.md).

## 1. Before you start

**Accounts.** You need:

- one or more **source accounts** running Gen3 with RDS or Aurora databases;
- one **central backup account** that no source account's administrators can change. A dedicated security or backup account is ideal. The examples use `111111111111` for the central account and `222222222222`, `333333333333` for source accounts.

**Same AWS Organization or not.** For each source account, find out whether it's in the same AWS Organization as the central account:

```sh
aws organizations describe-organization --query Organization.Id   # run in each account
```

| Source account is... | Use `cross_account_mode` |
|---|---|
| in the same org as the central account and will stay there | `aws_backup` (default) |
| in a different org, or may be moved between orgs (for billing, credits, a funder-owned org) | `snapshot_share` |

AWS Backup can only copy into another account's vault when both accounts are in the same org. `snapshot_share` uses RDS snapshot sharing instead, which works between any two accounts. If in doubt, choose `snapshot_share`.

**Tools.**

- Terraform 1.5 or newer (or Terragrunt)
- AWS provider 6.x and the `archive` provider
- credentials that can create IAM roles, KMS keys, AWS Backup plans and vaults, Lambda functions, EventBridge rules, SNS topics and CloudWatch alarms in each account

**Databases.** Every RDS database in a source account is backed up unless you list it in `excluded_dbs`. Databases must be encrypted, either with the default `aws/rds` key or a customer-managed key whose key policy allows IAM policies, which is the default policy.

## 2. Deploy the central backup account

Deploy `tf_files/aws/backup-destination` in the central account, in `us-east-1`.

Terraform:

```hcl
module "central_rds_backups" {
  source = "git::https://github.com/uc-cdis/gen3-terraform.git//tf_files/aws/backup-destination?ref=<commit or tag>"

  # Source accounts using cross_account_mode = "aws_backup": one vault is created per account.
  account_ids = ["222222222222"]

  # Source accounts using cross_account_mode = "snapshot_share".
  snapshot_share_source_accounts = ["333333333333"]

  # Alarm when no backup from an account has arrived for this many hours.
  # Use 30 for accounts with daily backups, 200 for weekly-only accounts.
  freshness_alarm_accounts = {
    "222222222222" = 30
    "333333333333" = 30
  }

  alert_email_addresses = ["platform-team@example.org"]
}
```

Terragrunt (`terragrunt.hcl` in the central account's folder):

```hcl
terraform {
  source = "git::https://github.com/uc-cdis/gen3-terraform.git//tf_files/aws/backup-destination?ref=<commit or tag>"
}

inputs = {
  account_ids                    = ["222222222222"]
  snapshot_share_source_accounts = ["333333333333"]
  freshness_alarm_accounts       = { "222222222222" = 30, "333333333333" = 30 }
  alert_email_addresses          = ["platform-team@example.org"]
}
```

Apply it **before** the source accounts. A source account in `aws_backup` mode fails every copy with `Access Denied` until its vault exists here.

If you'll have more than a few `snapshot_share` accounts, request an increase to the **RDS manual DB cluster snapshots** quota in the central account (Service Quotas → Amazon RDS; the default is 100 per region). Shared copies are stored as manual snapshots.

## 3. Deploy each source account

Deploy `tf_files/aws/backup` in each source account, in the region where the databases run.

```hcl
module "rds_backups" {
  source = "git::https://github.com/uc-cdis/gen3-terraform.git//tf_files/aws/modules/backup?ref=<commit or tag>"

  backup_destination_account = "111111111111" # your central account; required for cross-account copies
  cross_account_mode         = "aws_backup"   # or "snapshot_share"

  cross_region_destination = "us-west-1" # second region for the in-account copy
  daily_backups_enabled    = true
  excluded_dbs             = []           # ARNs of databases to skip

  alert_email_addresses = ["platform-team@example.org"]
}
```

With Terragrunt, point `terraform.source` at `//tf_files/aws/backup` and pass the same values as `inputs`.

**`backup_destination_account` must be set.** If it's left empty, the module creates only the two in-account copies and grants no other account access to anything.

### What gets created

| | Both modes | `snapshot_share` only |
|---|---|---|
| Backup plans | daily (optional), weekly, monthly, yearly | |
| Vaults | `rds-backup-vault` (home region), `rds-cross-region-backup-vault-<region>` | |
| KMS | one key per vault | `alias/rds-backup-share`, usable by the central account |
| Alerts | EventBridge rule → SNS `rds-backup-alerts` for failed jobs | Lambda error alarm |
| Lambda | | `rds-backup-share-snapshots`, hourly |

## 4. Confirm alerts

Each address in `alert_email_addresses` receives an **"AWS Notification – Subscription Confirmation"** email from SNS, one for every account it's subscribed in. Alerts aren't delivered until the link in that email is clicked.

## 5. Verify

The first scheduled backups run at 02:00 UTC (daily and weekly tiers). To test sooner, start an on-demand backup of a non-production cluster in a source account:

```sh
aws backup start-backup-job \
  --backup-vault-name rds-backup-vault \
  --resource-arn arn:aws:rds:us-east-1:222222222222:cluster:<cluster-id> \
  --iam-role-arn arn:aws:iam::222222222222:role/rds-backup-role \
  --lifecycle DeleteAfterDays=7
```

In `aws_backup` mode an on-demand backup isn't copied, because copies come from the backup plans, so check the copies after the first scheduled run. In `snapshot_share` mode the share Lambda picks up any completed backup in the vault, so the on-demand backup also tests the copy path within about two hours.

In each **source account**:

```sh
aws backup list-backup-jobs --by-created-after "$(date -u -v-1d +%FT%TZ)" \
  --query 'BackupJobs[].[ResourceArn,State]' --output table

aws backup list-copy-jobs --by-created-after "$(date -u -v-1d +%FT%TZ)" \
  --query 'CopyJobs[].[DestinationBackupVaultArn,State,StatusMessage]' --output table
```

(On Linux, use `date -u -d '1 day ago' +%FT%TZ`.)

In `snapshot_share` mode, also look for staging snapshots named `gen3xa-…` in the source account. Check the `/aws/lambda/rds-backup-share-snapshots` log group for errors.

In the **central account**:

```sh
# aws_backup mode: recovery points per source account
aws backup list-recovery-points-by-backup-vault --backup-vault-name rds-central-backup-vault-222222222222 \
  --query 'RecoveryPoints[].[CreationDate,ResourceArn]' --output table

# snapshot_share mode: copies made by the collector
aws rds describe-db-cluster-snapshots --snapshot-type manual \
  --query "DBClusterSnapshots[?starts_with(DBClusterSnapshotIdentifier,'gen3xa-333333333333')].[DBClusterSnapshotIdentifier,Status]" --output table
```

Each `rds-central-backup-stale-<account>` alarm should move to **OK** once that account's first copy arrives. Until then it shows ALARM, which is expected right after setup.

## 6. Options

| Goal | Setting |
|---|---|
| Send only longer-lived backups to the central account, to cut cost | `cross_account_min_retention_days = 365` sends only monthly and yearly. Use `30` for weekly and up; the default `0` sends everything. Aurora cross-account copies are full copies, so this is the biggest cost lever. |
| Skip daily backups | `daily_backups_enabled = false`. Use a freshness threshold of about 200 hours for that account. |
| Use your own SNS topic | `alert_sns_topic_arn` (both modules) |
| Different DR region | `cross_region_destination` |
| Keep `snapshot_share` staging copies for longer | `snapshot_share_staging_hours` (default 72) |

## 7. Moving an account to another AWS Organization

If an account in `aws_backup` mode moves to a different org from the central account, its cross-account copies start failing. Before the move:

1. In the central stack, add the account to `snapshot_share_source_accounts`, then apply.
2. In the account's stack, set `cross_account_mode = "snapshot_share"`, then apply.

Its vault in the central account can stay, and the recovery points already in it are kept until they expire. See the full checklist in [rds-backups.md](rds-backups.md#6-moving-an-account-between-aws-organizations).

## 8. Upgrading from an earlier version of this module

Earlier versions set `backup_destination_account` to a default account ID and `cross_account_backup = true`. When upgrading:

- **Set `backup_destination_account` explicitly** to your central account. If you leave it unset, the cross-account `copy_action`s are removed from your backup plans.
- If you never set it, your backup plans tried to copy to an account you don't control. Those copies always failed, so no data was copied. However, your `rds-backup-vault` KMS key policy granted that account access. Upgrading with `backup_destination_account` unset removes that key policy from Terraform. Afterwards, check the key policy in the KMS console and confirm it only lists your own accounts.

## 9. Troubleshooting

| Symptom (copy job `StatusMessage` or alarm) | Cause | Fix |
|---|---|---|
| `Copy job failed. Both source and destination account must be a member of the same organization.` | The source account isn't in the central account's org (or was moved) | Switch the account to `snapshot_share` (section 7) |
| `Access Denied trying to call AWS Backup service` | The central vault for this account doesn't exist | Add the account to `account_ids` and apply the central stack |
| `The KMS key encrypting source snapshot … does not exist, is not enabled, or you do not have permissions` | The database's KMS key doesn't let the central account use it, which `aws_backup` copies need | Allow the central account in that key's policy, or use `snapshot_share`, which re-encrypts with its own key |
| `SnapshotQuotaExceeded` in the collector log | The central account reached its manual snapshot quota | Request a quota increase (section 2) |
| `rds-central-backup-stale-<account>` in ALARM | No copy from that account for longer than the threshold | Check that account's copy jobs and, in `snapshot_share` mode, its share Lambda log |
| `rds-backup-share-snapshots-errors` in ALARM | The share Lambda failed, often from concurrent-copy limits; it retries hourly | Read `/aws/lambda/rds-backup-share-snapshots`; if errors persist, check the database KMS key policy |

## 10. Turning it off

- To stop cross-account copies for one account, set `cross_account_backup = false` and apply. Local backups continue.
- To remove everything, run `terraform destroy` on the source stack. AWS Backup won't delete a vault that still holds recovery points. Let them expire, or delete them first if your retention policy allows it.
