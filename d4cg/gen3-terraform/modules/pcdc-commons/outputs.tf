output "aurora_cluster_master_username" {
  description = "Aurora cluster master username"
  value       = module.commons.aurora_cluster_master_username
}

output "aurora_cluster_master_password" {
  description = "Aurora cluster master user's password"
  value       = module.commons.aurora_cluster_master_password
  sensitive   = true
}

output "aurora_cluster_writer_endpoint" {
  description = "Aurora cluster writer instance endpoint"
  value       = module.commons.aurora_cluster_writer_endpoint
}

output "es_endpoint" {
  value = module.commons.es_endpoint
}

output "eks_cluster_endpoint" {
  value     = module.commons.eks_cluster_endpoint
  sensitive = true
}

output "eks_cluster_ca_cert" {
  value     = module.commons.eks_cluster_ca_cert
  sensitive = true
}

output "eks_cluster_name" {
  value = module.commons.eks_cluster_name
}

output "eks_oidc_arn" {
  value = module.commons.eks_oidc_arn
}

output "fence-bot_user_id" {
  value = module.commons.fence-bot_user_id
}

output "fence-bot_user_secret" {
  value     = module.commons.fence-bot_user_secret
  sensitive = true
}

output "data-bucket_name" {
  value = module.commons.data-bucket_name
}

output "amanuensis-bot_user_id" {
  value = module.amanuensis-bot-user.bot_id
}

output "amanuensis-bot_user_secret" {
  value     = module.amanuensis-bot-user.bot_secret
  sensitive = true
}

output "data-release-bucket_name" {
  value = module.amanuensis-data-release-bucket.bucket_name
}

