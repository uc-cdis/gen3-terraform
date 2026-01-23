variable "vpc_name" {
  description = "The name of the VPC, and will be used to identify most resources created within the module"
  type        = string
}

variable "aws_region" {
  description = "The AWS region where the resources will be created in"
  type        = string
}

variable "kubernetes_namespace" {
  description = "The namespace your gen3 deployment will use"
  type        = string
  default     = "default"
}

variable "availability_zones" {
  description = "The availability zones where the resources will be created in. There should be 3 availability zones"
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) == 3
    error_message = "Exactly 3 availability zones must be provided."
  }
}

variable "hostname" {
  description = "The hostname for your gen3 deployment"
  type        = string
}

variable "es_linked_role" {
  description = "Whether to create elasticsearch service linked role. Set to false if already created in account"
  type        = bool
  default     = false
}

variable "revproxy_arn" {
  description = "The ARN of the certificate in ACM"
  type        = string
}

variable "create_gitops_infra" {
  description = "Whether or not to create users/buckets needed for useryaml gitops management"
  type        = bool
  default     = true
}

variable "user_yaml_bucket_name" {
  description = "The name of the S3 bucket where the user.yaml file will be stored"
  type        = string
}

variable "default_tags" {
  description = "Default tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}

# Cognito Variables
variable "deploy_cognito" {
  description = "Whether to deploy Cognito resources"
  type        = bool
  default     = true
}

variable "user_pool_name" {
  description = "The name of the Cognito user pool"
  type        = string
  default     = null
}

variable "app_client_name" {
  description = "The name of the Cognito app client"
  type        = string
  default     = null
}

variable "domain_prefix" {
  description = "The domain prefix for Cognito hosted UI"
  type        = string
  default     = null
}

variable "callback_urls" {
  description = "List of allowed callback URLs for Cognito"
  type        = list(string)
  default     = []
}

variable "logout_urls" {
  description = "List of allowed logout URLs for Cognito"
  type        = list(string)
  default     = []
}

variable "allowed_oauth_flows" {
  description = "List of allowed OAuth flows"
  type        = list(string)
  default     = ["code"]
}

variable "allowed_oauth_scopes" {
  description = "List of allowed OAuth scopes"
  type        = list(string)
  default     = ["email", "openid", "phone", "profile"]
}

variable "supported_identity_providers" {
  description = "List of supported identity providers"
  type        = list(string)
  default     = ["COGNITO"]
}