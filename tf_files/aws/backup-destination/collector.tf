# ======================================================================
# Central collector (hourly):
#   - copies RDS snapshots shared by snapshot_share_source_accounts into
#     this account under central_backup_key, and deletes them when the
#     delete-at date encoded in their name passes;
#   - publishes Gen3Backup/HoursSinceLastCopy per freshness_alarm_accounts
#     entry, alarming when an account's copies stop arriving (e.g. after
#     an AWS Organization move breaks AWS Backup cross-account copy).
# ======================================================================

locals {
  collector_enabled = length(var.snapshot_share_source_accounts) > 0 || length(var.freshness_alarm_accounts) > 0
  alert_topic_arn   = var.alert_sns_topic_arn != "" ? var.alert_sns_topic_arn : aws_sns_topic.alerts[0].arn
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_sns_topic" "alerts" {
  count             = var.alert_sns_topic_arn == "" ? 1 : 0
  name              = "rds-central-backup-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_policy" "alerts" {
  count = var.alert_sns_topic_arn == "" ? 1 : 0
  arn   = aws_sns_topic.alerts[0].arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudWatch"
      Effect    = "Allow"
      Principal = { Service = "cloudwatch.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.alerts[0].arn
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
}

resource "aws_sns_topic_subscription" "alert_email" {
  for_each  = toset(var.alert_email_addresses)
  topic_arn = local.alert_topic_arn
  protocol  = "email"
  endpoint  = each.value
}

data "archive_file" "collector" {
  count       = local.collector_enabled ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/lambda/collector.py"
  output_path = "${path.module}/lambda/collector.zip"
}

resource "aws_iam_role" "collector" {
  count = local.collector_enabled ? 1 : 0
  name  = "rds-central-backup-collector"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "collector" {
  count = local.collector_enabled ? 1 : 0
  name  = "collector"
  role  = aws_iam_role.collector[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid      = "ReadCentralVaults"
        Effect   = "Allow"
        Action   = ["backup:ListRecoveryPointsByBackupVault"]
        Resource = "*"
      },
      {
        Sid    = "CopyAndExpireSnapshots"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBClusterSnapshots", "rds:DescribeDBSnapshots",
          "rds:CopyDBClusterSnapshot", "rds:CopyDBSnapshot",
          "rds:DeleteDBClusterSnapshot", "rds:DeleteDBSnapshot",
          "rds:AddTagsToResource"
        ]
        Resource = "*"
      },
      {
        Sid      = "CentralKey"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:CreateGrant", "kms:ReEncrypt*", "kms:GenerateDataKey*"]
        Resource = aws_kms_key.central_backup_key.arn
      },
      {
        Sid       = "Metrics"
        Effect    = "Allow"
        Action    = "cloudwatch:PutMetricData"
        Resource  = "*"
        Condition = { StringEquals = { "cloudwatch:namespace" = "Gen3Backup" } }
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.collector[0].arn}:*"
      }
      ], length(var.snapshot_share_source_accounts) == 0 ? [] : [{
        # Source accounts' share keys (rds-backup-share) grant this account; this allows the role to use them.
        Sid      = "SourceShareKeys"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:CreateGrant", "kms:ReEncrypt*"]
        Resource = [for a in var.snapshot_share_source_accounts : "arn:aws:kms:*:${a}:key/*"]
    }])
  })
}

resource "aws_cloudwatch_log_group" "collector" {
  count             = local.collector_enabled ? 1 : 0
  name              = "/aws/lambda/rds-central-backup-collector"
  retention_in_days = 90
}

resource "aws_lambda_function" "collector" {
  count            = local.collector_enabled ? 1 : 0
  function_name    = "rds-central-backup-collector"
  description      = "Copies shared RDS snapshots into central backup and reports per-account backup freshness"
  role             = aws_iam_role.collector[0].arn
  runtime          = "python3.12"
  handler          = "collector.handler"
  filename         = data.archive_file.collector[0].output_path
  source_code_hash = data.archive_file.collector[0].output_base64sha256
  timeout          = 900
  memory_size      = 256

  environment {
    variables = {
      SOURCE_ACCOUNTS  = join(",", sort(tolist(var.snapshot_share_source_accounts)))
      MONITOR_ACCOUNTS = join(",", sort(keys(var.freshness_alarm_accounts)))
      KMS_KEY_ARN      = aws_kms_key.central_backup_key.arn
      VAULT_PREFIX     = "rds-central-backup-vault-"
    }
  }

  depends_on = [aws_cloudwatch_log_group.collector]
}

resource "aws_cloudwatch_event_rule" "collector" {
  count               = local.collector_enabled ? 1 : 0
  name                = "rds-central-backup-collector"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "collector" {
  count = local.collector_enabled ? 1 : 0
  rule  = aws_cloudwatch_event_rule.collector[0].name
  arn   = aws_lambda_function.collector[0].arn
}

resource "aws_lambda_permission" "collector" {
  count         = local.collector_enabled ? 1 : 0
  statement_id  = "AllowEventBridgeSchedule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collector[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.collector[0].arn
}

resource "aws_cloudwatch_metric_alarm" "collector_errors" {
  count               = local.collector_enabled ? 1 : 0
  alarm_name          = "rds-central-backup-collector-errors"
  alarm_description   = "Central backup collector failed (shared snapshot copy/expiry or freshness reporting)"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.collector[0].function_name }
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

resource "aws_cloudwatch_metric_alarm" "freshness" {
  for_each            = var.freshness_alarm_accounts
  alarm_name          = "rds-central-backup-stale-${each.key}"
  alarm_description   = "No RDS backup copy from account ${each.key} has reached the central backup account in ${each.value}h. Check the source account's copy jobs (an AWS Organization move breaks aws_backup mode)."
  namespace           = "Gen3Backup"
  metric_name         = "HoursSinceLastCopy"
  dimensions          = { SourceAccount = each.key }
  statistic           = "Maximum"
  period              = 3600
  evaluation_periods  = 2
  threshold           = each.value
  comparison_operator = "GreaterThanThreshold"
  # The collector not reporting at all is itself a failure.
  treat_missing_data = "breaching"
  alarm_actions      = [local.alert_topic_arn]
  ok_actions         = [local.alert_topic_arn]
}
