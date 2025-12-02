data "aws_caller_identity" "current" {}

locals {
  account_ids = distinct(compact(concat(
    var.account_ids,
    ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
  )))
}

resource "aws_kms_key" "kms_key" {}

resource "aws_kms_alias" "kms_key_alias" {
  name          = "alias/${var.alias_name}"
  target_key_id = aws_kms_key.kms_key.id
}

resource "aws_kms_key_policy" "example" {
  key_id = aws_kms_key.kms_key.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }

        Resource = "*"
        Sid      = "Enable IAM User Permissions"
      },
      {
        Sid       = "Allow use of the key"
        Effect    = "Allow"
        Principal = { AWS = local.account_ids }
        Action    = var.action
        Resource  = "*"
      }
    ]
  })
}

