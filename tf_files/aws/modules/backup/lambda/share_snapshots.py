"""Share AWS Backup RDS/Aurora recovery points with a backup account in any AWS Organization.

Runs hourly and is idempotent; each run picks up whatever the previous run left unfinished:
  1. For each recent COMPLETED recovery point in SOURCE_VAULT_NAME, ensure a staging snapshot
     encrypted with SHARE_KMS_KEY_ARN exists (AWS Backup snapshots cannot be shared directly).
  2. Share available staging snapshots with DESTINATION_ACCOUNT.
  3. Delete staging snapshots older than STAGING_HOURS.

The staging snapshot name carries the retention to the destination, which cannot read tags of a
snapshot shared from another account:
    gen3xa-<created YYYYMMDDHHMM>-<delete-at YYYYMMDD>-<db identifier>
"""
import datetime as dt
import logging
import os

import boto3
from botocore.exceptions import ClientError

log = logging.getLogger()
log.setLevel(logging.INFO)

PREFIX = "gen3xa-"
CLUSTER_TYPES = {"Aurora", "Neptune", "DocumentDB"}

backup = boto3.client("backup")
rds = boto3.client("rds")

VAULT = os.environ["SOURCE_VAULT_NAME"]
DEST = os.environ["DESTINATION_ACCOUNT"]
KEY = os.environ["SHARE_KMS_KEY_ARN"]
MIN_DAYS = int(os.environ.get("MIN_RETENTION_DAYS", "0"))
STAGING_HOURS = int(os.environ.get("STAGING_HOURS", "72"))
TYPES = {t.strip() for t in os.environ.get("RESOURCE_TYPES", "Aurora,RDS").split(",") if t.strip()}


class Api:
    """Uniform wrapper over the cluster- and instance-snapshot flavours of the RDS API."""

    def __init__(self, cluster):
        self.cluster = cluster
        self.kind = "DBClusterSnapshot" if cluster else "DBSnapshot"

    def describe(self, **kw):
        fn = rds.describe_db_cluster_snapshots if self.cluster else rds.describe_db_snapshots
        key = "DBClusterSnapshots" if self.cluster else "DBSnapshots"
        for page in rds.get_paginator(fn.__name__).paginate(**kw):
            yield from page[key]

    def get(self, ident):
        kw = {"DBClusterSnapshotIdentifier" if self.cluster else "DBSnapshotIdentifier": ident}
        try:
            return next(self.describe(**kw), None)
        except ClientError as e:
            if e.response["Error"]["Code"] in ("DBClusterSnapshotNotFoundFault", "DBSnapshotNotFound"):
                return None
            raise

    def ident(self, snap):
        return snap["DBClusterSnapshotIdentifier" if self.cluster else "DBSnapshotIdentifier"]

    def copy(self, source_arn, target):
        if self.cluster:
            rds.copy_db_cluster_snapshot(
                SourceDBClusterSnapshotIdentifier=source_arn, TargetDBClusterSnapshotIdentifier=target,
                KmsKeyId=KEY, Tags=[{"Key": "gen3-backup-share", "Value": DEST}])
        else:
            rds.copy_db_snapshot(
                SourceDBSnapshotIdentifier=source_arn, TargetDBSnapshotIdentifier=target,
                KmsKeyId=KEY, Tags=[{"Key": "gen3-backup-share", "Value": DEST}])

    def shared_with(self, ident):
        if self.cluster:
            res = rds.describe_db_cluster_snapshot_attributes(DBClusterSnapshotIdentifier=ident)
            attrs = res["DBClusterSnapshotAttributesResult"]["DBClusterSnapshotAttributes"]
        else:
            res = rds.describe_db_snapshot_attributes(DBSnapshotIdentifier=ident)
            attrs = res["DBSnapshotAttributesResult"]["DBSnapshotAttributes"]
        return {v for a in attrs if a["AttributeName"] == "restore" for v in a["AttributeValues"]}

    def share(self, ident):
        if self.cluster:
            rds.modify_db_cluster_snapshot_attribute(
                DBClusterSnapshotIdentifier=ident, AttributeName="restore", ValuesToAdd=[DEST])
        else:
            rds.modify_db_snapshot_attribute(
                DBSnapshotIdentifier=ident, AttributeName="restore", ValuesToAdd=[DEST])

    def delete(self, ident):
        if self.cluster:
            rds.delete_db_cluster_snapshot(DBClusterSnapshotIdentifier=ident)
        else:
            rds.delete_db_snapshot(DBSnapshotIdentifier=ident)


def staging_name(rp):
    created = rp["CreationDate"]
    delete_at = rp["CalculatedLifecycle"]["DeleteAt"]
    db = rp["ResourceArn"].split(":")[-1]
    return f"{PREFIX}{created:%Y%m%d%H%M}-{delete_at:%Y%m%d}-{db}"[:255].rstrip("-")


def recovery_points(since):
    pages = backup.get_paginator("list_recovery_points_by_backup_vault").paginate(
        BackupVaultName=VAULT, ByCreatedAfter=since)
    for page in pages:
        for rp in page["RecoveryPoints"]:
            if rp.get("Status") == "COMPLETED" and rp.get("ResourceType") in TYPES:
                yield rp


def handler(event, context):
    now = dt.datetime.now(dt.timezone.utc)
    errors = 0

    # 1 + 2: stage and share recent recovery points.
    for rp in recovery_points(now - dt.timedelta(hours=STAGING_HOURS)):
        lifecycle = rp.get("CalculatedLifecycle", {})
        if "DeleteAt" not in lifecycle:
            continue
        if (lifecycle["DeleteAt"] - rp["CreationDate"]).days < MIN_DAYS:
            continue
        api = Api(rp["ResourceType"] in CLUSTER_TYPES)
        name = staging_name(rp)
        try:
            snap = api.get(name)
            if snap is None:
                log.info("staging %s from %s", name, rp["RecoveryPointArn"])
                api.copy(rp["RecoveryPointArn"], name)
            elif snap["Status"] == "available" and DEST not in api.shared_with(name):
                log.info("sharing %s with %s", name, DEST)
                api.share(name)
        except ClientError as e:
            # Concurrent-copy and quota limits are expected; the next run retries.
            log.error("%s: %s", name, e)
            errors += 1

    # 3: drop staging copies once the destination has had time to collect them.
    cutoff = now - dt.timedelta(hours=STAGING_HOURS)
    for api in (Api(True), Api(False)):
        for snap in api.describe(SnapshotType="manual"):
            ident = api.ident(snap)
            if ident.startswith(PREFIX) and snap["Status"] == "available" and snap["SnapshotCreateTime"] < cutoff:
                log.info("deleting expired staging snapshot %s", ident)
                try:
                    api.delete(ident)
                except ClientError as e:
                    log.error("%s: %s", ident, e)
                    errors += 1

    if errors:
        # Fail the invocation so the Lambda Errors alarm fires.
        raise RuntimeError(f"{errors} snapshot operations failed; see log")
    return {"ok": True}
