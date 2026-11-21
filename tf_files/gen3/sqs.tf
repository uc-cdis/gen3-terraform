module "audit-sqs" {
  source = "../aws/modules/sqs"
  sqs_name = "${var.vpc_name}-audit"
}

module "ssjdispatcher-sqs" {
  source = "../aws/modules/sqs"
  sqs_name = "${var.vpc_name}-ssjdispatcher"
}
