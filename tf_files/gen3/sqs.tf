module "audit-sqs" {
  source = "../aws/sqs"
  sqs_name = "audit"
}

module "ssjdispatcher-sqs" {
  source = "../aws/sqs"
  sqs_name = "ssjdispatcher"
}
