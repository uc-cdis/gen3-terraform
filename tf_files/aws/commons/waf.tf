module "aws_waf" {
  source                            = "../modules/waf"
  count                             = var.deploy_waf ? 1 : 0
  vpc_name                          = var.vpc_name
  base_rules                        = var.base_rules
  additional_rules                  = var.additional_rules
  ip_set_rules                      = var.ip_set_rules
  custom_rule_groups                = var.custom_rule_groups
  depends_on                        = [module.cdis_vpc.vpc_id, module.cdis_vpc.vpc_peering_id]
}