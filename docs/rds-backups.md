# RDS / Aurora backups for Gen3

This page covers the account-wide RDS backup modules in this repo: what they create, where backups
end up, how to configure them, and how to restore. It also explains what breaks when an AWS account
moves between AWS Organizations, and how to avoid it.

| Module | Deploy in | Purpose |
|---|---|---|
| `tf_files/aws/backup` (wraps `modules/backup`) | every account that runs Gen3 databases | backup plans, local and cross-region vaults, cross-account copy, alerts |
| `tf_files/aws/backup-destination` | one central backup account | one vault per source account, collector for shared snapshots, freshness alarms |

## 1. Where backups live

Every recovery point ends up in three places:

| # | Location | Account | Region | Protects against |
|---|---|---|---|---|
| Vault 1 | `rds-backup-vault` | source | home region (us-east-1) | operator error, bad migrations; fastest restore |
| Vault 2 | `rds-cross-region-backup-vault-<region>` | source | `cross_region_destination` (default us-west-1) | regional outage |
| Vault 3 | `rds-central-backup-vault-<source account>` (AWS Backup) **or** `gen3xa-<source account>-…` manual snapshots (snapshot share) | central backup account | us-east-1 | compromise, deletion, or loss of the source account |

## 2. How backups are created

AWS Backup selects every RDS resource in the account (`arn:aws:rds:*`, minus `excluded_dbs`) on four
schedules. Each tier copies to Vault 2 and, if enabled, to Vault 3, with the same retention everywhere.

| Tier | Schedule (UTC) | Retention | Toggle |
|---|---|---|---|
| daily | 02:00 every day | 7 days | `daily_backups_enabled` |
| weekly | 02:00 Saturday | 30 days | always on |
| monthly | 03:00 on the 1st | 365 days | always on |
| yearly | 04:00 Jan 1 | 2555 days (7 years) | always on |

### Getting backups into the central account

AWS Backup can copy into another account's vault **only when both accounts belong to the same AWS
Organization.** If an account moves to a different org (for billing, credits, or a funder-owned org),
every cross-account copy fails with:

```
Copy job failed. Both source and destination account must be a member of the same organization.
```

Local backups (Vaults 1 and 2) keep working, so nothing looks wrong unless someone checks. For this
reason the module has two modes, set with `cross_account_mode`:

| Mode | How | Use when |
|---|---|---|
| `aws_backup` (default) | `copy_action` into `rds-central-backup-vault-<account>` | the account is in the same org as the central account and is not expected to move |
| `snapshot_share` | A Lambda in the source account copies each recovery point to a staging snapshot (`gen3xa-<created>-<delete-at>-<db>`) under a shareable KMS key and shares it with the central account. The central collector copies it under the central key and deletes it on the `<delete-at>` date. | the account is in a different org, or it may move |

`snapshot_share` works no matter which org either account is in, so an account can move orgs without
any Terraform change. Its trade-offs:

- Each staging copy is a full snapshot in the source account. It's kept for `snapshot_share_staging_hours` (default 72) and then deleted.
- Copies in the central account are **manual** snapshots and count toward the RDS manual-snapshot quota (default 100 per region). Raise the quota before adding many accounts.
- If the source Lambda is down for longer than the staging window, those recovery points are not sent. The freshness alarm (below) catches this.

### Alerts

- **Source account:** an EventBridge rule sends any `FAILED`, `ABORTED`, `EXPIRED` or `PARTIAL` backup or copy job to SNS (`rds-backup-alerts`, or your own topic via `alert_sns_topic_arn`). In `snapshot_share` mode, errors from the share Lambda also raise an alarm.
- **Central account:** the hourly collector publishes `Gen3Backup/HoursSinceLastCopy` for each entry in `freshness_alarm_accounts`, covering both modes. An alarm fires when an account's copies stop arriving. This works even when nobody is watching the source account.

Subscribe email addresses with `alert_email_addresses`. Each recipient has to confirm the SNS subscription.

## 3. Configuration

Source account (`tf_files/aws/backup`):

```hcl
inputs = {
  daily_backups_enabled      = true
  excluded_dbs               = []           # cluster/instance ARNs to skip
  cross_region_destination   = "us-west-1"
  cross_account_backup       = true
  backup_destination_account = "<central account id>"
  cross_account_mode         = "aws_backup" # or "snapshot_share"
  # Only send tiers retained at least this long to the central account.
  # 0 = all tiers, 30 = weekly and up, 365 = monthly and yearly.
  cross_account_min_retention_days = 0
  alert_email_addresses            = ["platform-team@example.org"]
}
```

Central account (`tf_files/aws/backup-destination`):

```hcl
inputs = {
  account_ids                    = ["<source>", ...] # aws_backup-mode accounts get a vault
  snapshot_share_source_accounts = ["<source>", ...] # snapshot_share-mode accounts
  freshness_alarm_accounts       = { "<source>" = 30 } # max hours between copies: 30 daily, 200 weekly
  alert_email_addresses          = ["platform-team@example.org"]
}
```

For a new account, add it to `account_ids` (and/or `snapshot_share_source_accounts`) and to
`freshness_alarm_accounts` **before** applying the source stack. Otherwise its first copies fail
with `Access Denied`.

### Cost notes

Aurora snapshot copies to another account or region are **full** copies, not incremental ones. The
central account therefore stores about `(7 daily + 4 weekly + 12 monthly + yearlies) × cluster size`
per cluster. Ways to reduce it:

- `cross_account_min_retention_days = 365`: send only monthly and yearly backups to the central account. Dailies and weeklies still exist in Vaults 1 and 2.
- When a database shrinks a lot, the old monthly and yearly copies keep their original size until they expire, which can be years for yearlies. Review and prune them deliberately.
- AWS Backup has no cold-storage tier for Aurora or RDS. For long-term archives, consider exporting snapshots to S3 and archiving them in Glacier. Exports are Parquet data, though, and can't be restored directly as a database.

## 4. Restoration scenarios

| Scenario | Use | Notes |
|---|---|---|
| Bad deploy, data deleted or corrupted | Vault 1 | Pick the newest recovery point from before the incident. |
| Home region unavailable | Vault 2 | Restore in the DR region; the networking, subnet group and security groups must already exist there. |
| Source account compromised or lost | Vault 3 | Restore in the central account, or into a recovery account (see below). |
| Point-in-time inside the RDS retention window | RDS automated backups | Separate from AWS Backup; uses the cluster's own `backup_retention_period`. |

## 5. Restoration procedures

### From Vault 1 or 2 (AWS Backup)

1. In AWS Backup, choose **Protected resources** → the cluster → the recovery point → **Restore**. Or from the CLI:
   ```sh
   aws backup get-recovery-point-restore-metadata --backup-vault-name rds-backup-vault --recovery-point-arn <arn>
   aws backup start-restore-job --recovery-point-arn <arn> --iam-role-arn <rds-backup-role arn> --metadata file://meta.json
   ```
   Give the restored cluster a **new** identifier. Never restore over the live cluster.
2. **Aurora restores create a cluster with no instances.** Add a writer instance:
   `aws rds create-db-instance --db-cluster-identifier <new> --db-instance-identifier <new>-1 --engine aurora-postgresql --db-instance-class <class>`
3. Check that the cluster is reachable and the data is what you expect (row counts, latest timestamps for the key tables).
4. Point the Gen3 services at it (update the `*-creds` secrets or Helm values, or the DNS), then restart them.
5. Watch for errors. Keep the old cluster until the restore has been accepted.
6. Record the recovery point used, the restore duration and the validation results.

### From Vault 3, `aws_backup` mode

Recovery points that AWS Backup manages can't be shared directly. Either:

- restore in the central account (same steps as above), then snapshot the restored cluster and share that snapshot with the recovery account; or
- copy the recovery point back to a vault in the recovery account with AWS Backup. This only works if both accounts are in the same org.

### From Vault 3, `snapshot_share` mode

The copies are ordinary manual snapshots (`gen3xa-<source>-<created>-<delete-at>-<db>`), encrypted
with the central backup KMS key.

1. To restore in the central account: `aws rds restore-db-cluster-from-snapshot --snapshot-identifier gen3xa-... --db-cluster-identifier <new> --engine aurora-postgresql --kms-key-id <key>`, then add an instance.
2. To restore in another account, which can be in any org: add that account to the central KMS key policy (Decrypt, DescribeKey, CreateGrant), then `aws rds modify-db-cluster-snapshot-attribute --attribute-name restore --values-to-add <account>`, and copy or restore the snapshot from that account.

### Test restores

Restore a non-production database from each vault type at least once a year, and after any change to
these modules. Record the results.

## 6. Moving an account between AWS Organizations

Checklist for PE when an account is about to change orgs:

**Before the move**
- [ ] Is the account in `aws_backup` mode and moving away from the central account's org? Switch it to `cross_account_mode = "snapshot_share"`, add it to `snapshot_share_source_accounts` in the central stack, and apply both.
- [ ] Look for `aws:PrincipalOrgID`, `aws:PrincipalOrgPaths` or `aws:ResourceOrgID` conditions in S3 bucket, KMS, SNS, SQS and ECR policies that this account relies on, both its own and other accounts' that grant access by org.
- [ ] Note which SCPs, tag policies and backup policies the current org applies. The new org's will apply instead.
- [ ] Find the org-level services this account depends on: IAM Identity Center (SSO) permission sets, the organization CloudTrail trail, GuardDuty, Security Hub and Config aggregators, RAM shares scoped to the org, and Cost Explorer categories.
- [ ] Note Savings Plans and Reserved Instances. Their benefit is shared within an org's payer.

**After the move**
- [ ] Within 24 hours, confirm that local backups ran (`aws backup list-backup-jobs --by-created-after <date>`) and that the next cross-account copy succeeded (`list-copy-jobs`, or the central account's `HoursSinceLastCopy` metric).
- [ ] Check the alert topics for failures. Confirm the freshness alarm for the account is `OK`.
- [ ] Confirm SSO access, CloudTrail delivery and security tooling still work for the account.
