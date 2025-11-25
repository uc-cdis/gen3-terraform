variable "kms_key_arn" {
  description = "ARN of existing KMS key. If not provided, a new key will be created"
  type        = string
  default     = null
}

variable "account_ids" {
  description = "List of AWS account IDs that can access the secret"
  type        = list(string)
}

variable "secret_name" {
  description = "Name of the Secrets Manager secret"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}