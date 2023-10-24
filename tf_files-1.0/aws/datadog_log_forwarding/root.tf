terraform {
  backend "s3" {
    encrypt = "true"
  }
}


locals {
  api_key = var.secrets_manager_enabled ? jsondecode(data.aws_secretsmanager_secret_version.secrets.secret_string)["api-key"] : var.datadog_api_key
}

# We're not going to use the S3 bucket module because it adds a bunch of extra stuff we don't need
# for this application
resource "aws_s3_bucket" "fargate_logs_backup_bucket" {
    bucket = "${var.environment}-fargate-logs-backup"

    tags = {
        Name = "${var.environment}-fargate-logs-backup"
        Environment = var.environment
    }
}

# I think buckets are private by default, but doesn't hurt to be sure
resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.fargate_logs_backup_bucket.id
  acl    = "private"
}

resource "aws_iam_role" "fargate_logs_backup_bucket_writer" {
  name = "bucket_writer_${var.environment}-fargate-logs-backup"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "firehose.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "fargate_logs_backup_bucket_writer" {
  name        = "bucket_writer_${var.environment}-fargate-logs-backup"
  description = "Read or write ${var.environment}-fargate-logs-backup"
  policy      = data.aws_iam_policy_document.fargate_logs_backup_bucket_writer.json
}

resource "aws_iam_role_policy_attachment" "fargate_logs_backup_bucket_reader" {
  role       = aws_iam_role.fargate_logs_backup_bucket_writer.name
  policy_arn = aws_iam_policy.fargate_logs_backup_bucket_writer.arn
}

# We're now going to make the cloudwatch subscription filter
resource "aws_cloudwatch_log_subscription_filter" "fargate_log_filter" {
    name = "datadog_fargate_filter"
    destination_arn = aws_kinesis_firehose_delivery_stream.fargate_logs_to_datadog.arn
    filter_pattern = var.filter_pattern
    #TODO put a link to the output configuration
    #This is hardcoded here:
    log_group_name = "fluent-bit-eks-cloudwatch"
}

#And the Kinesis Firehose
resource "aws_kinesis_firehose_delivery_stream" "fargate_logs_to_datadog" {
    name = "fargate_logs_to_datadog_forwarder"
    destination = "http_endpoint"

    http_endpoint_configuration {
        url = "https://aws-kinesis-http-intake.logs.ddog-gov.com/v1/input"
        name = "Datadog"
        access_key = local.api_key
        s3_backup_mode = "FailedDataOnly"

        s3_configuration = {
            role_arn = aws_iam_role.fargate_logs_backup_bucket_writer.fargate_logs_backup_bucket_writer
            bucket_arn = aws_s3_bucket.fargate_logs_backup_bucket.arn
        }
    }
}