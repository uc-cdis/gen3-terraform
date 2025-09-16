resource "aws_wafv2_web_acl" "waf" {
  name  = "${var.vpc_name}-waf"
  description = "WAF per environment for tailored security."
  scope       = "REGIONAL"

  default_action {
    allow {}
  }
  # --- Managed rules ---
  dynamic "rule" {
    for_each = concat(var.base_rules, var.additional_rules)
    content {
      name     = "AWS-${rule.value.managed_rule_group_name}"
      priority = rule.value.priority
      override_action {
        dynamic "count" {
          for_each = rule.value.count ? [1] : []
          content {}
        }
        dynamic "none" {
          for_each = rule.value.count ? [] : [1]
          content {}
        }
      }
      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = rule.value.managed_rule_group_name

          dynamic "rule_action_override" {
            for_each = length(rule.value.override_to_count) > 0 ? rule.value.override_to_count : []
            content {
              action_to_use {
                count {}
              }
              name = rule_action_override.value
            }
          }
          dynamic "rule_action_override" {
            for_each = length(rule.value.override_to_allow) > 0 ? rule.value.override_to_allow : []
            content {
              action_to_use {
                allow {}
              }
              name = rule_action_override.value
            }
          }
        }
      }

      visibility_config {
        sampled_requests_enabled   = true
        cloudwatch_metrics_enabled = true
        metric_name                = "AWS-${rule.value.managed_rule_group_name}"
      }
    }
  }

  # --- Customer-managed Rule Groups ---
  dynamic "rule" {
    for_each = var.custom_rule_groups
    content {
      name     = rule.value.name
      priority = rule.value.priority

      # Like managed groups, RuleGroupReference supports override_action = count|none
      override_action {
        dynamic "count" {
          for_each = rule.value.count ? [1] : []
          content {}
        }
        dynamic "none" {
          for_each = rule.value.count ? [] : [1]
          content {}
        }
      }

      statement {
        rule_group_reference_statement {
          arn = rule.value.arn

          # Optionally force specific rules to Count
          dynamic "rule_action_override" {
            for_each = rule.value.override_to_count
            content {
              name = rule_action_override.value
              action_to_use { 
                count {}
                }
            }
          }
          # Optionally force specific rules to Allow
          dynamic "rule_action_override" {
            for_each = rule.value.override_to_allow
            content {
              name = rule_action_override.value
              action_to_use { 
                allow {} 
                }
            }
          }
        }
      }

      visibility_config {
        sampled_requests_enabled   = true
        cloudwatch_metrics_enabled = true
        metric_name                = "RG-${rule.value.name}"
      }
    }
  }

  dynamic "rule" {
    for_each = { for r in var.ip_set_rules : r.name => r }
    content {
      name     = "IPSET-${rule.value.name}"
      priority = rule.value.priority

      statement {
        ip_set_reference_statement {
          arn = rule.value.ip_set_arn
        }
      }

      # IP sets use action{}, not override_action{}
      dynamic "action" {
        for_each = rule.value.action == "allow" ? [1] : []
        content { 
          allow {} 
          }
      }
      dynamic "action" {
        for_each = rule.value.action == "block" ? [1] : []
        content { 
          block {} 
          }
      }
      dynamic "action" {
        for_each = rule.value.action == "count" ? [1] : []
        content { 
          count {} 
          }
      }
      dynamic "action" {
        for_each = rule.value.action == "captcha" ? [1] : []
        content { 
          captcha {} 
          }
      }
      dynamic "action" {
        for_each = rule.value.action == "challenge" ? [1] : []
        content { 
          challenge {} 
          }
      }

      visibility_config {
        sampled_requests_enabled   = true
        cloudwatch_metrics_enabled = true
        metric_name                = "ipset_${replace(rule.value.name, "/[^A-Za-z0-9]/", "_")}"
      }
    }
  }

  tags = {
    Environment = "${var.vpc_name}"
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "WebAclMetrics"
    sampled_requests_enabled   = false
  }
}