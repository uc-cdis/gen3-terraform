output "gitops_user_access_key_id" {
  description = "Access Key ID for the gitops-user"
  value       = aws_iam_access_key.gitops_key[0].id
}

output "gitops_user_secret_access_key" {
  description = "Secret Access Key for the gitops-user"
  value       = aws_iam_access_key.gitops_key[0].secret
  sensitive = true
}
