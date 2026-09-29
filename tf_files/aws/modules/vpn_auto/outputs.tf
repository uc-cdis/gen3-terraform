output "vpn_nlb_dns_name" {
  description = "DNS name of the VPN network load balancer"
  value       = aws_lb.vpn_nlb.dns_name
}

output "vpn_fqdn" {
  description = "The CNAME clients connect to, empty if this module is not managing DNS"
  value       = var.manage_dns_record ? aws_route53_record.vpn[0].fqdn : ""
}

output "vpn_s3_bucket_name" {
  description = "Bucket holding the VPN PKI, whether this stack's own or one adopted via s3_prefix_override"
  value       = local.pki_bucket_name
}

output "vpn_asg_name" {
  description = "Name of the autoscaling group, handy for the cattle test"
  value       = aws_autoscaling_group.vpn.name
}

output "vpn_security_group_id" {
  description = "Inbound security group, so other stacks can allow the VPN in"
  value       = aws_security_group.vpn_in.id
}

output "vpn_log_group_name" {
  value = aws_cloudwatch_log_group.vpn_log_group.name
}
