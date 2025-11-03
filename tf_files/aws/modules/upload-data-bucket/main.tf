module "data-bucket-queue" {
  source                         = "../data-bucket-queue"
  bucket_name                    = aws_s3_bucket.data_bucket.id
  configure_bucket_notifications = false
  encryption_enabled             = var.encryption_enabled
  kms_key_id                     = var.kms_key_id != "" ? var.kms_key_id : (length(module.kms-key) > 0 ? module.kms-key[0].kms_arn : null)
}

module "cloud-trail" {
  count                = var.deploy_cloud_trail ? 1 : 0
  source               = "../cloud-trail"
  vpc_name             = var.vpc_name
  environment          = var.environment
  cloudwatchlogs_group = var.cloudwatchlogs_group
  bucket_arn           = aws_s3_bucket.data_bucket.arn
  bucket_id            = aws_s3_bucket.log_bucket.id
}

module "kms-key" {
  count  = var.encryption_enabled && var.kms_key_id == "" ? 1 : 0
  source = "../kms-key"
  alias_name = "${var.vpc_name}-sns-sqs-key"
}