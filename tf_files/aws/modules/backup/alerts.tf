# ======================================================================
# Alert on failed backup / copy jobs. AWS Backup fails silently by
# default: e.g. moving this account to another AWS Organization makes every
# cross-account copy fail while local backups keep succeeding.
# ======================================================================

resource "aws_sns_topic" "alerts" {
  count             = var.alert_sns_topic_arn == "" ? 1 : 0
  name              = "rds-backup-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_policy" "alerts" {
  count = var.alert_sns_topic_arn == "" ? 1 : 0
  arn   = aws_sns_topic.alerts[0].arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridgeAndCloudWatch"
        Effect    = "Allow"
        Principal = { Service = ["events.amazonaws.com", "cloudwatch.amazonaws.com"] }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.alerts[0].arn
        Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "alert_email" {
  for_each  = toset(var.alert_email_addresses)
  topic_arn = local.alert_topic_arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_event_rule" "backup_job_failures" {
  name        = "rds-backup-job-failures"
  description = "AWS Backup backup or copy job did not complete"
  event_pattern = jsonencode({
    source        = ["aws.backup"]
    "detail-type" = ["Backup Job State Change", "Copy Job State Change"]
    detail        = { state = ["FAILED", "ABORTED", "EXPIRED", "PARTIAL"] }
  })
}

resource "aws_cloudwatch_event_target" "backup_job_failures" {
  rule = aws_cloudwatch_event_rule.backup_job_failures.name
  arn  = local.alert_topic_arn

  input_transformer {
    input_paths = {
      account = "$.account"
      type    = "$.detail-type"
      state   = "$.detail.state"
      reason  = "$.detail.statusMessage"
      vault   = "$.detail.destinationBackupVaultArn"
      res     = "$.detail.resourceArn"
    }
    input_template = "\"[<account>] <type>: <state> for <res> -> <vault>. Reason: <reason>\""
  }
}
