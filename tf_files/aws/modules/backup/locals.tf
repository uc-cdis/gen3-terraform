locals {
  # Cross-account copy only happens when a destination account is set explicitly.
  cross_account_enabled = var.cross_account_backup && var.backup_destination_account != null

  tier_retention_days = {
    daily   = 7
    weekly  = 30
    monthly = 365
    yearly  = 2555
  }

  xacct_tier_enabled = {
    for tier, days in local.tier_retention_days :
    tier => local.cross_account_enabled && days >= var.cross_account_min_retention_days
  }

  aws_backup_copy_tiers = {
    for tier, enabled in local.xacct_tier_enabled :
    tier => enabled && var.cross_account_mode == "aws_backup"
  }

  snapshot_share_enabled = local.cross_account_enabled && var.cross_account_mode == "snapshot_share"

  alert_topic_arn = var.alert_sns_topic_arn != "" ? var.alert_sns_topic_arn : aws_sns_topic.alerts[0].arn
}
