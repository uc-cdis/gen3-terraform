data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Filter out local zones, they can't host these subnets
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

# The VPN instances need CloudWatch Logs, and read/write on the bucket holding
# the PKI so a replacement instance can recover the certs instead of generating new ones
data "aws_iam_policy_document" "vpn_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:GetLogEvents",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy",
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.vpn_certs_and_files.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.vpn_certs_and_files.arn}/*"]
  }
}

data "aws_ami" "vpn_ami" {
  most_recent = true
  owners      = [var.ami_account_id]

  filter {
    name   = "name"
    values = [var.image_name_search_criteria]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
