module "data-release-bucket" {
  source            = "../../../../tf_files/aws/modules/s3-bucket"
  bucket_name       = "${var.vpc_name}-data-release-bucket"
  environment       = var.vpc_name
  cloud_trail_count = 0
}

resource "aws_s3_bucket_versioning" "data-release-bucket" {
  bucket = module.data-release-bucket.bucket_name

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "data-release-bucket" {
  bucket = module.data-release-bucket.bucket_name

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
