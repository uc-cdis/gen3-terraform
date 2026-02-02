variable "vpc_name" {}

variable "slack_webhook_secret_name" {
  description = "Optional override for the Secrets Manager secret name."
  type        = string
  default     = null
}

variable "es_name" {
  default = ""
}