variable commons_name {
  description = "This is the name of the specific commons you are running. Each commons will only have access to its own secrets"
}

variable oidc_provider_id {}

variable account_number {
  description = "AWS account ID to use"
}

variable "aws_region" {
  description = "AWS region where the EKS cluster is deployed"
  type        = string
  default     = "us-east-1"
}