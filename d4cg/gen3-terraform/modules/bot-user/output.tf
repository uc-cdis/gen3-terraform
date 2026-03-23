output "bot_secret" {
  value = aws_iam_access_key.bot_user_key.secret
}

output "bot_id" {
  value = aws_iam_access_key.bot_user_key.id
}
