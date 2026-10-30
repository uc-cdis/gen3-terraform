module "audit-sqs" {
  source = "../aws/modules/sqs"
  sqs_name = "audit"
}

module "ssjdispatcher-sqs" {
  count    = var.upload_bucket == "" ? 1 : 0
  source   = "../aws/modules/sqs"
  sqs_name = "ssjdispatcher"
}

moved {
  from = module.ssjdispatcher-sqs
  to   = module.ssjdispatcher-sqs[0]
}

module "ssjdispatcher-upload-queue" {
  count                          = var.upload_bucket != "" ? 1 : 0
  source                         = "../aws/modules/data-bucket-queue"
  bucket_name                    = var.upload_bucket
  configure_bucket_notifications = var.ssjdispatcher_configure_bucket_notifications
}

locals {
  ssjdispatcher_sqs_url = var.upload_bucket != "" ? module.ssjdispatcher-upload-queue[0].sqs-url : module.ssjdispatcher-sqs[0].sqs-url
  ssjdispatcher_sqs_arn = var.upload_bucket != "" ? module.ssjdispatcher-upload-queue[0].sqs-arn : module.ssjdispatcher-sqs[0].sqs-arn
}
