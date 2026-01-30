module "cloudwatch_alarms" {
  source                            = "../modules/cloudwatch-alarms"
  count                             = var.deploy_cloudwatch_alarms ? 1 : 0
  vpc_name                          = var.vpc_name
  slack_webhook_secret_name         = var.slack_webhook_secret_name
  es_name                           = var.es_name
  depends_on                        = [module.cdis_vpc.vpc_id, module.commons_vpc_es.es_arn]
}