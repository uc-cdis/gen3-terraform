data "aws_secretsmanager_secret" "slack_webhook" {
  name = coalesce(
    var.slack_webhook_secret_name,
    "${var.vpc_name}-slack-webhook"
  )
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function_payload.zip"
}