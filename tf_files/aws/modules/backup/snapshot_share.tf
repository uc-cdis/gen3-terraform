# ======================================================================
# Org-independent cross-account copy ("snapshot_share" mode).
#
# AWS Backup can only copy into a vault in another account when both
# accounts belong to the same AWS Organization. Plain RDS snapshot sharing
# has no such restriction, so for accounts outside the central account's
# org, a scheduled Lambda:
#   1. copies each new AWS Backup RDS/Aurora recovery point to a staging
#      snapshot encrypted with a KMS key the destination account may use
#      (AWS Backup snapshots, and snapshots under aws/rds, cannot be shared),
#   2. shares the staging snapshot with the destination account,
#   3. deletes staging snapshots after snapshot_share_staging_hours.
# The destination's collector (backup-destination module) copies shared
# snapshots under its own key and deletes them on the source's schedule.
# Retention travels in the snapshot name: gen3xa-<created>-<delete-at>-<db>.
# ======================================================================

resource "aws_kms_key" "share_key" {
  count                   = local.snapshot_share_enabled ? 1 : 0
  description             = "Encrypts RDS snapshots shared with backup account ${var.backup_destination_account}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "BackupAccountUseForSnapshotCopy"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.backup_destination_account}:root" }
        Action    = ["kms:Decrypt", "kms:DescribeKey", "kms:CreateGrant", "kms:ReEncrypt*", "kms:GenerateDataKey*"]
        Resource  = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "share_key" {
  count         = local.snapshot_share_enabled ? 1 : 0
  name          = "alias/rds-backup-share"
  target_key_id = aws_kms_key.share_key[0].key_id
}

data "archive_file" "share_snapshots" {
  count       = local.snapshot_share_enabled ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/lambda/share_snapshots.py"
  output_path = "${path.module}/lambda/share_snapshots.zip"
}

resource "aws_iam_role" "share_snapshots" {
  count = local.snapshot_share_enabled ? 1 : 0
  name  = "rds-backup-share-snapshots"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "share_snapshots" {
  count = local.snapshot_share_enabled ? 1 : 0
  name  = "share-snapshots"
  role  = aws_iam_role.share_snapshots[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadRecoveryPoints"
        Effect   = "Allow"
        Action   = ["backup:ListRecoveryPointsByBackupVault"]
        Resource = aws_backup_vault.rds_backup_vault.arn
      },
      {
        Sid    = "StageAndShareSnapshots"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBClusterSnapshots", "rds:DescribeDBSnapshots",
          "rds:CopyDBClusterSnapshot", "rds:CopyDBSnapshot",
          "rds:ModifyDBClusterSnapshotAttribute", "rds:ModifyDBSnapshotAttribute",
          "rds:DescribeDBClusterSnapshotAttributes", "rds:DescribeDBSnapshotAttributes",
          "rds:DeleteDBClusterSnapshot", "rds:DeleteDBSnapshot",
          "rds:AddTagsToResource", "rds:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        # Decrypt the source snapshot (DB's own key) and encrypt the staging copy.
        Sid       = "KmsForSnapshotCopy"
        Effect    = "Allow"
        Action    = ["kms:Decrypt", "kms:DescribeKey", "kms:CreateGrant", "kms:ReEncrypt*", "kms:GenerateDataKey*"]
        Resource  = "*"
        Condition = { StringEquals = { "kms:ViaService" = "rds.${data.aws_region.current.region}.amazonaws.com" } }
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.share_snapshots[0].arn}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "share_snapshots" {
  count             = local.snapshot_share_enabled ? 1 : 0
  name              = "/aws/lambda/rds-backup-share-snapshots"
  retention_in_days = 90
}

resource "aws_lambda_function" "share_snapshots" {
  count            = local.snapshot_share_enabled ? 1 : 0
  function_name    = "rds-backup-share-snapshots"
  description      = "Shares AWS Backup RDS snapshots with backup account ${var.backup_destination_account}"
  role             = aws_iam_role.share_snapshots[0].arn
  runtime          = "python3.12"
  handler          = "share_snapshots.handler"
  filename         = data.archive_file.share_snapshots[0].output_path
  source_code_hash = data.archive_file.share_snapshots[0].output_base64sha256
  timeout          = 900
  memory_size      = 256

  environment {
    variables = {
      SOURCE_VAULT_NAME   = aws_backup_vault.rds_backup_vault.name
      DESTINATION_ACCOUNT = var.backup_destination_account
      SHARE_KMS_KEY_ARN   = aws_kms_key.share_key[0].arn
      MIN_RETENTION_DAYS  = tostring(var.cross_account_min_retention_days)
      STAGING_HOURS       = tostring(var.snapshot_share_staging_hours)
      RESOURCE_TYPES      = join(",", var.snapshot_share_resource_types)
    }
  }

  depends_on = [aws_cloudwatch_log_group.share_snapshots]
}

resource "aws_cloudwatch_event_rule" "share_snapshots" {
  count               = local.snapshot_share_enabled ? 1 : 0
  name                = "rds-backup-share-snapshots"
  description         = "Hourly reconcile of RDS snapshots shared with the backup account"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "share_snapshots" {
  count = local.snapshot_share_enabled ? 1 : 0
  rule  = aws_cloudwatch_event_rule.share_snapshots[0].name
  arn   = aws_lambda_function.share_snapshots[0].arn
}

resource "aws_lambda_permission" "share_snapshots" {
  count         = local.snapshot_share_enabled ? 1 : 0
  statement_id  = "AllowEventBridgeSchedule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.share_snapshots[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.share_snapshots[0].arn
}

resource "aws_cloudwatch_metric_alarm" "share_snapshots_errors" {
  count               = local.snapshot_share_enabled ? 1 : 0
  alarm_name          = "rds-backup-share-snapshots-errors"
  alarm_description   = "The snapshot-share Lambda failed; snapshots are not reaching account ${var.backup_destination_account}"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.share_snapshots[0].function_name }
  statistic           = "Sum"
  period              = 3600
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.alert_topic_arn]
  ok_actions          = [local.alert_topic_arn]
}
