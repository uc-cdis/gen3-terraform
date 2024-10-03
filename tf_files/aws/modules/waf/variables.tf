variable "vpc_name" {
  default = "devplanetv2"
}

variable "base_rules" {
  description = "Base AWS Managed Rules"
  type = list(object({
    priority = number
    managed_rule_group_name = string
  }))
  default = [
    {
      managed_rule_group_name = "AWSManagedRulesAmazonIpReputationList"
      priority = 0
    },
    {
      managed_rule_group_name = "AWSManagedRulesPHPRuleSet"
      priority = 1
    },
    {
      managed_rule_group_name = "AWSManagedRulesWordPressRuleSet"
      priority = 2
    },
  ]
}

variable "additional_rules" {
  description = "Additional AWS Managed Rules"
  type = list(object({
    priority = number
    managed_rule_group_name = string
  }))
  default = []
}
