module "audit-sqs" {
  source = "../aws/modules/sqs"
  sqs_name = "audit"
}

module "audit-sqs" {
  source = "../aws/modules/sqs"
  sqs_name = "ssjdispatcher"
}