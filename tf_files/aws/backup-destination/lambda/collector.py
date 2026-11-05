"""Central backup collector. Runs hourly and is idempotent.

1. Copy RDS snapshots shared by SOURCE_ACCOUNTS (backup module, snapshot_share mode) into this
   account, re-encrypted with KMS_KEY_ARN, so they survive loss of the source account.
       shared:  gen3xa-<created>-<delete-at>-<db>              (owned by the source account)
       local:   gen3xa-<source account>-<created>-<delete-at>-<db>
2. Delete local copies whose <delete-at> (YYYYMMDD, UTC) has passed.
3. Publish Gen3Backup/HoursSinceLastCopy{SourceAccount} for MONITOR_ACCOUNTS: hours since the
   newest copy from that account landed here, by either path (AWS Backup copy into
   VAULT_PREFIX<account>, or step 1).
"""
import datetime as dt
import logging
import os
import re

import boto3
from botocore.exceptions import ClientError

log = logging.getLogger()
log.setLevel(logging.INFO)

PREFIX = "gen3xa-"
SHARED_RE = re.compile(r"^gen3xa-(\d{12})-(\d{8})-(.+)$")          # created, delete-at, db
LOCAL_RE = re.compile(r"^gen3xa-(\d{12})-(\d{12})-(\d{8})-(.+)$")  # account, created, delete-at, db

rds = boto3.client("rds")
backup = boto3.client("backup")
cloudwatch = boto3.client("cloudwatch")

SOURCES = {a for a in os.environ.get("SOURCE_ACCOUNTS", "").split(",") if a}
MONITOR = [a for a in os.environ.get("MONITOR_ACCOUNTS", "").split(",") if a]
KEY = os.environ["KMS_KEY_ARN"]
VAULT_PREFIX = os.environ.get("VAULT_PREFIX", "rds-central-backup-vault-")

FLAVOURS = [
    # (describe op, list key, id field, arn field, copy fn name, source arg, target arg, delete fn, delete arg)
    ("describe_db_cluster_snapshots", "DBClusterSnapshots", "DBClusterSnapshotIdentifier",
     "DBClusterSnapshotArn", "copy_db_cluster_snapshot", "SourceDBClusterSnapshotIdentifier",
     "TargetDBClusterSnapshotIdentifier", "delete_db_cluster_snapshot", "DBClusterSnapshotIdentifier"),
    ("describe_db_snapshots", "DBSnapshots", "DBSnapshotIdentifier",
     "DBSnapshotArn", "copy_db_snapshot", "SourceDBSnapshotIdentifier",
     "TargetDBSnapshotIdentifier", "delete_db_snapshot", "DBSnapshotIdentifier"),
]


def snapshots(op, key, **kw):
    for page in rds.get_paginator(op).paginate(**kw):
        yield from page[key]


def handler(event, context):
    now = dt.datetime.now(dt.timezone.utc)
    today = now.strftime("%Y%m%d")
    errors = 0
    newest = {}  # account -> newest copy time seen here

    for op, key, id_f, arn_f, copy_fn, src_arg, tgt_arg, del_fn, del_arg in FLAVOURS:
        local = {}
        for s in snapshots(op, key, SnapshotType="manual"):
            ident = s[id_f]
            m = LOCAL_RE.match(ident)
            if not m:
                continue
            local[ident] = s
            acct, _, delete_at, _ = m.groups()
            if s["Status"] == "available":
                t = s["SnapshotCreateTime"]
                newest[acct] = max(newest.get(acct, t), t)
                if delete_at < today:
                    log.info("expiring %s (delete-at %s)", ident, delete_at)
                    try:
                        getattr(rds, del_fn)(**{del_arg: ident})
                    except ClientError as e:
                        log.error("%s: %s", ident, e)
                        errors += 1

        if not SOURCES:
            continue
        for s in snapshots(op, key, SnapshotType="shared", IncludeShared=True):
            arn = s[arn_f]
            acct = arn.split(":")[4]
            name = arn.split(":", 6)[-1]
            m = SHARED_RE.match(name)
            if acct not in SOURCES or not m or s["Status"] != "available":
                continue
            created, delete_at, db = m.groups()
            if delete_at < today:
                continue
            target = f"{PREFIX}{acct}-{created}-{delete_at}-{db}"[:255].rstrip("-")
            if target in local:
                continue
            log.info("copying %s -> %s", arn, target)
            try:
                getattr(rds, copy_fn)(**{
                    src_arg: arn, tgt_arg: target, "KmsKeyId": KEY,
                    "Tags": [
                        {"Key": "gen3-backup-source-account", "Value": acct},
                        {"Key": "gen3-backup-delete-at", "Value": delete_at},
                    ],
                })
            except ClientError as e:
                # Concurrent-copy and quota limits are expected; the next run retries.
                log.error("%s: %s", target, e)
                errors += 1

    # Freshness: also consider AWS Backup copies in the per-account central vaults.
    since = now - dt.timedelta(days=60)
    metrics = []
    for acct in MONITOR:
        try:
            pages = backup.get_paginator("list_recovery_points_by_backup_vault").paginate(
                BackupVaultName=f"{VAULT_PREFIX}{acct}", ByCreatedAfter=since)
            for page in pages:
                for rp in page["RecoveryPoints"]:
                    if rp.get("Status") == "COMPLETED":
                        t = rp["CreationDate"]
                        newest[acct] = max(newest.get(acct, t), t)
        except ClientError as e:
            # A missing vault is normal for snapshot_share accounts.
            if e.response["Error"]["Code"] not in ("ResourceNotFoundException", "AccessDeniedException"):
                log.error("vault for %s: %s", acct, e)
                errors += 1
        hours = (now - newest[acct]).total_seconds() / 3600 if acct in newest else 24 * 365
        log.info("account %s: %.1f hours since last copy", acct, hours)
        metrics.append({"MetricName": "HoursSinceLastCopy", "Value": hours, "Unit": "None",
                        "Dimensions": [{"Name": "SourceAccount", "Value": acct}]})

    for i in range(0, len(metrics), 500):
        cloudwatch.put_metric_data(Namespace="Gen3Backup", MetricData=metrics[i:i + 500])

    if errors:
        raise RuntimeError(f"{errors} operations failed; see log")
    return {"ok": True, "accounts": {a: str(newest.get(a)) for a in MONITOR}}
