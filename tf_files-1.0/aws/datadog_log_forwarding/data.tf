data "aws_iam_policy_document" "fargate_logs_backup_bucket_writer" {
  statement {
    actions   = ["s3:Get*","s3:List*"]
    effect    = "Allow"
    resources = [aws_s3_bucket.fargate_logs_backup_bucket.arn, "${aws_s3_bucket.fargate_logs_backup_bucket.arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject","s3:GetObject","s3:DeleteObject"]
    resources = ["${aws_s3_bucket.fargate_logs_backup_bucket.arn}/*"]
  }
}

data "aws_secretsmanager_secret_version" "secrets" {
  secret_id = data.aws_secretsmanager_secret.dd_keys.id
}

data "aws_secretsmanager_secret" "dd_keys" {
    arn = var.datadog_secrets_manager_arn
}