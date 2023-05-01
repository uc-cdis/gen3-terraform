## Policies data 
data "aws_iam_policy_document" "data_bucket_reader" {
  statement {
    actions   = ["s3:Get*","s3:List*"]
    effect    = "Allow"
    resources = [aws_s3_bucket.data_bucket.arn, "${aws_s3_bucket.data_bucket.arn}/*"]
  }
}

data "aws_iam_policy_document" "data_bucket_writer" {
  statement {
    actions   = ["s3:PutObject"]
    effect    = "Allow"
    resources = [aws_s3_bucket.data_bucket.arn, "${aws_s3_bucket.data_bucket.arn}/*"]
  }
}

## Role and policies for the log bucket
data "aws_iam_policy_document" "log_bucket_writer" {
  statement {
    actions = ["s3:Get*","s3:List*"]
    effect    = "Allow"
    resources = [aws_s3_bucket.log_bucket.arn, "${aws_s3_bucket.log_bucket.arn}/*"]
  }

  statement {
    effect = "Allow"
    actions = ["s3:PutObject","s3:GetObject","s3:DeleteObject"]
    resources = ["${aws_s3_bucket.log_bucket.arn}/*"]
  }

}
