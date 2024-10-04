##
# Output WAF arn
##

output "waf_arn" {
  description = "WAF arn - annotate the cluster ingress"
  value       = aws_wafv2_web_acl.waf.arn
}