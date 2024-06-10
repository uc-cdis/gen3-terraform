resource "aws_kms_key" "kms_key" {}

resource "aws_kms_key_policy" "example" {
  key_id = aws_kms_key.kms_key.id
  policy = jsonencode({
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }

        Resource = "*"
        Sid      = "Enable IAM User Permissions"
      },
      {
        Action = var.action
        Effect = "Allow"
        Principal = {
          AWS = var.account_ids
        }

        Resource = "*"
        Sid      = "Allow use of the key"

      },
    ]
    Version = "2012-10-17"
  })
}
