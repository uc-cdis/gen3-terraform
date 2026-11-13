variable "account_ids" {
  type        = list(string)
  description = "List of account ids to grant access to the bucket"
  default     = []
}

variable "action" {
  type        = list(string)
  description = "List of actions to grant access to the bucket"
  default     = ["kms:Decrypt"]
}

variable "alias_name" {
  type        = string
  description = "Alias name for the KMS key"
  default     = ""
}

# More info on automatic key rotation:
# https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html
variable "enable_key_rotation" {
  type        = bool
  description = "Enable automatic rotation of the KMS key material"
  default     = true
}
