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
  dynamic "statement" {
    for_each = var.account_folders
    content {
      sid    = "AllowList_${replace(statement.key, "-", "")}"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${statement.key}:root"]
      }

      actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
      resources = ["arn:aws:s3:::${var.bucket_name}"]

      condition {
        test     = "StringLike"
        variable = "s3:prefix"

        values = distinct(
          flatten([
            for prefix in statement.value : [
              prefix,
              "${prefix}*",
            ]
          ])
        )
      }
    }
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
