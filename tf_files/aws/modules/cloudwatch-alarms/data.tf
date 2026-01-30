data "aws_secretsmanager_secret" "slack_webhook" {
  name = coalesce(
    var.slack_webhook_secret_name,
    "${var.vpc_name}-slack-webhook"
  )
}