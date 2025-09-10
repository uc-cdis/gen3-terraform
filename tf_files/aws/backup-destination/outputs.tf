output "kms_key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.central_backup_key.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.central_backup_key.arn
}

output "backup_vault_names" {
  description = "Names of all created backup vaults"
  value       = [for vault in aws_backup_vault.account_vaults : vault.name]
}

output "backup_vault_arns" {
  description = "ARNs of all created backup vaults"
  value       = { for account_id, vault in aws_backup_vault.account_vaults : account_id => vault.arn }
}