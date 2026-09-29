output "vpn_nlb_dns_name" {
  value = module.vpn_auto.vpn_nlb_dns_name
}

output "vpn_fqdn" {
  value = module.vpn_auto.vpn_fqdn
}

output "vpn_s3_bucket_name" {
  value = module.vpn_auto.vpn_s3_bucket_name
}

output "vpn_asg_name" {
  value = module.vpn_auto.vpn_asg_name
}

output "vpn_security_group_id" {
  value = module.vpn_auto.vpn_security_group_id
}

output "vpn_log_group_name" {
  value = module.vpn_auto.vpn_log_group_name
}
