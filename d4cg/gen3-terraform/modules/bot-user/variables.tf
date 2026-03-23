variable "vpc_name" {}

variable "bucket_name" {}

variable "bot_name" {}

variable "bucket_access_arns" {
  description = "When the user / service bot has to access another bucket that wasn't created by the VPC module"
  default     = []
}
