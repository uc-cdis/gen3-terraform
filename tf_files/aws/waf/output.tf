##
# Output WAF arn
##

output "waf_arn" {
  description = "WAF arn - annotate the cluster ingress"
  value       = module.aws_waf[0].waf_arn
}