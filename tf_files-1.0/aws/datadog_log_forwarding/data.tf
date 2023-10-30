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

data "aws_iam_policy_document" "firehose_access" {
  statement {
    effect    = "Allow"
    actions   = ["firehose:PutRecord","firehose:PutRecordBatch"] 
    resources = ["${aws_kinesis_firehose_delivery_stream.fargate_logs_to_datadog.arn}"]
  }
}

data "aws_secretsmanager_secret_version" "secrets" {
  secret_id = data.aws_secretsmanager_secret.dd_keys.id
}

data "aws_secretsmanager_secret" "dd_keys" {
  arn = var.datadog_secrets_manager_arn
}