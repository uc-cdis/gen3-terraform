resource "aws_wafv2_web_acl" "waf" {
  name  = "${var.vpc_name}-waf"
  description = "WAF per environment for tailored security."
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = concat(var.base_rules, var.additional_rules)
    content {
      name     = "AWS-${rule.value.managed_rule_group_name}"
      priority = rule.value.priority
      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = rule.value.managed_rule_group_name
        }
      }
      visibility_config {
        sampled_requests_enabled   = true
        cloudwatch_metrics_enabled = true
        metric_name                = "AWS-${rule.value.managed_rule_group_name}"
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