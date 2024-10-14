variable "vpc_name" {}

variable "base_rules" {
  description = "Base AWS Managed Rules"
  type = list(object({
    managed_rule_group_name = string
    priority = number
    override_to_count = list(string)
  }))
  default = [
    {
      managed_rule_group_name = "AWSManagedRulesAmazonIpReputationList"
      priority = 0
      override_to_count = ["AWSManagedReconnaissanceList"]
    },
    {
      managed_rule_group_name = "AWSManagedRulesPHPRuleSet"
      priority = 1
      override_to_count = ["PHPHighRiskMethodsVariables_HEADER", "PHPHighRiskMethodsVariables_QUERYSTRING", "PHPHighRiskMethodsVariables_BODY"]
    },
    {
      managed_rule_group_name = "AWSManagedRulesWordPressRuleSet"
      priority = 2
      override_to_count= ["WordPressExploitableCommands_QUERYSTRING", "WordPressExploitablePaths_URIPATH"]
    },
  ]
}

variable "additional_rules" {
  description = "Additional AWS Managed Rules"
  type = list(object({
    managed_rule_group_name = string
    priority = number
    override_to_count = list(string)
  }))
  default = []
}
