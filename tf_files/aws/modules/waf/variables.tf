variable "vpc_name" {}

variable "base_rules" {
  description = "Base AWS Managed Rules"
  type = list(object({
    managed_rule_group_name = string
    priority = number
    override_to_count = list(string)
    count = bool
  }))
  default = [
    {
      managed_rule_group_name = "AWSManagedRulesAmazonIpReputationList"
      priority = 0
      override_to_count = ["AWSManagedReconnaissanceList"]
      count = false
    },
    {
      managed_rule_group_name = "AWSManagedRulesPHPRuleSet"
      priority = 1
      override_to_count = ["PHPHighRiskMethodsVariables_HEADER", "PHPHighRiskMethodsVariables_QUERYSTRING", "PHPHighRiskMethodsVariables_BODY"]
      count = false
    },
    {
      managed_rule_group_name = "AWSManagedRulesWordPressRuleSet"
      priority = 2
      override_to_count= ["WordPressExploitableCommands_QUERYSTRING", "WordPressExploitablePaths_URIPATH"]
      count = false
    },
    {
      managed_rule_group_name = "AWSManagedRulesAdminProtectionRuleSet"
      priority = 3
      override_to_count= ["AdminProtection_URIPATH"]
      count = false
    },
    {
      managed_rule_group_name = "AWSManagedRulesCommonRuleSet"
      priority = 4
      override_to_count= []
      count = true
    },
    {
      managed_rule_group_name = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 5
      override_to_count= []
      count = true
    },
    {
      managed_rule_group_name = "AWSManagedRulesLinuxRuleSet"
      priority = 6
      override_to_count= []
      count = true
    },
    {
      managed_rule_group_name = "AWSManagedRulesBotControlRuleSet"
      priority = 7
      override_to_count= []
      count = true
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

variable "custom_rule_groups" {
  description = "References to customer-managed WAFv2 Rule Groups."
  type = list(object({
    name              = string
    priority          = number
    arn               = string 
    count             = optional(bool, false)
    excluded_rules    = optional(list(string), [])
    override_to_count = optional(list(string), [])
  }))
  default = []
}
