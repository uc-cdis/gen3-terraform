resource "aws_s3_bucket" "mybucket" {
  bucket = var.bucket_name

  lifecycle {
    ignore_changes  = ["tags", "tags_all"]
  }  
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default_kms_encryption" {
  count  = var.kms_key_id != "" ? 1 : 0
  bucket = aws_s3_bucket.mybucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kms_key_encryption" {
  count  = var.kms_key_id != "" ? 0 : 1
  bucket = aws_s3_bucket.mybucket.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "mybucket" {
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
  bucket        = aws_s3_bucket.mybucket.id
  target_bucket = var.logging_bucket_name
  target_prefix = "log/${var.bucket_name}/"
}

resource "aws_s3_bucket_ownership_controls" "mybucket" {
  bucket = aws_s3_bucket.mybucket.id

  rule {
    object_ownership = var.bucket_ownership
  }
}
