terraform {
  backend "s3" {
    encrypt = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "AllowList"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [
        for account_id in keys(var.account_folders) :
        "arn:aws:iam::${account_id}:root"
      ]
    }

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]

    resources = ["arn:aws:s3:::${var.bucket_name}"]
  }

  dynamic "statement" {
    for_each = var.account_folders
    content {
      sid    = "AllowGet_${replace(statement.key, "-", "")}"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${statement.key}:root"]
      }

      actions = [
        "s3:GetObject",
      ]

      resources = [
        for prefix in statement.value :
        "arn:aws:s3:::${var.bucket_name}/${prefix}/user.yaml"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = var.bucket_name
  policy = data.aws_iam_policy_document.this.json
}
