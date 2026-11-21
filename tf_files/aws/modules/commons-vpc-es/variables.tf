variable "vpc_name" {}

variable "es_name" {
  default = ""
}

variable "vpc_id" {
  default = ""
}

variable "instance_type" {
  default = "m4.large.elasticsearch"
}

variable "ebs_volume_size_gb" {
  default = 20
}

variable "encryption" {
  default = "true"
}

variable "instance_count" {
  default = 3
}

variable "organization_name" {
  description = "For tagging purposes"
  default     = "Basic Service"
}

variable "es_version" {
  description = "What version to use when deploying ES"
  default     = "7.10"
}

variable "es_linked_role" {
  description = "Whether or no to deploy a linked roll for ES"
  default     = true
}

variable "role_arn" {
  description = "ARN of the IAM role or user to grant ES access. Must be set explicitly so Terraform tracks the dependency from the ES domain back to the IAM principal; omitting it forces a data-source lookup by name which breaks implicit ordering on the first apply."
  type        = string

  validation {
    condition     = var.role_arn != ""
    error_message = "role_arn must be provided explicitly. Passing an empty string causes the module to look up the IAM principal by name via a data source, breaking the implicit dependency and introducing a race condition on first apply."
  }
}

variable "deploy_cloudwatch_alarm" {
  default = false
}

variable "slack_webhook_secret_name" {
  description = "Optional override for the Secrets Manager secret name."
  type        = string
  default     = null
}
