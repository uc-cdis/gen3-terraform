variable "csoc_account_id" {
  default = "433568766270"
}

variable "account_name" {}

variable "alarm_actions" {}

variable "csoc_alerts_sns_arn" {
  description = "ARN of the CSOC security alerts SNS topic used by the alerting Lambda"
  type        = string
  default     = "arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-for-bsd-security"
}
