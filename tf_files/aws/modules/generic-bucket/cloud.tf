resource "aws_s3_bucket" "mybucket" {
  bucket = var.bucket_name

  lifecycle {
    ignore_changes  = ["tags", "tags_all"]
  }  
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default_kms_encryption" {
  count  = var.aes_encryption ? 0 : var.kms_key_id != "" ? 0 : 1
  bucket = aws_s3_bucket.mybucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kms_key_encryption" {
  count  = var.aes_encryption ? 0 : var.kms_key_id != "" ? 1 : 0
  bucket = aws_s3_bucket.mybucket.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "aes_encryption" {
  count  = var.aes_encryption ? 1: 0
  bucket = aws_s3_bucket.mybucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "mybucket" {
  count  = var.bucket_lifecycle_configuration != "" ? 1 : 0
  bucket = aws_s3_bucket.mybucket.id
  rule {
      status  = "Enabled"
      id      = "mybucket"
      abort_incomplete_multipart_upload {
        days_after_initiation = 7
      }
  }
}

resource "aws_s3_bucket_logging" "mybucket" {
  count         = var.logging_bucket_name != "" ? 1 : 0
  bucket        = aws_s3_bucket.mybucket.id
  target_bucket = var.logging_bucket_name
  target_prefix = "log/${var.bucket_name}/"

  lifecycle {
    ignore_changes  = all
  }    
}

resource "aws_s3_bucket_ownership_controls" "mybucket" {
  bucket = aws_s3_bucket.mybucket.id

  rule {
    object_ownership = var.bucket_ownership
  }
}

resource "aws_s3_bucket_public_access_block" "mybucket" {
  count  = var.public_access_block ? 1 : 0
  bucket = aws_s3_bucket.mybucket.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

resource "aws_s3_bucket_versioning" "name" {
  count   = var.versioning ? 1 : 0
  bucket  = aws_s3_bucket.mybucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "mybucket" {
  count  = var.policy_role_arn != "" ? 1 : 0
  bucket = aws_s3_bucket.mybucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          "AWS" = var.policy_role_arn
        },
        Action    = var.policy_actions,
        Resource  = [aws_s3_bucket.mybucket.arn, "${aws_s3_bucket.mybucket.arn}/*"]
      }
    ]
  })
}
