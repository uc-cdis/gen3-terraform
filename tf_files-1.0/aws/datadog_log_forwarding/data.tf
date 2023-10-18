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