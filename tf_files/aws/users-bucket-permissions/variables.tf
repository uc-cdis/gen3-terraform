variable "bucket_name" {
  description = "Name of the S3 bucket to attach the policy to"
  type        = string
}

variable "account_folders" {
  description = <<EOT
Example:
{
  "111111111111" = ["abc"]
  "222222222222" = ["def", "ghi"]
}
EOT
  type = map(list(string))
}
