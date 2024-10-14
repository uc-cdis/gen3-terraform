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
  description = "The ARN of the role to use for ES"
  default     = ""
}
