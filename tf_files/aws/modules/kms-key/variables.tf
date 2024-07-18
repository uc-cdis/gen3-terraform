variable "account_ids" {
  type        = list(string)
  description = "List of account ids to grant access to the bucket"
}

variable "action" {
  type        = list(string)
  description = "List of actions to grant access to the bucket"
  default     = ["kms:Decrypt"]
}
