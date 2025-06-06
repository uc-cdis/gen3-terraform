variable "role_name" {
  description = "Name for the role to be created"
}

variable aws_account_id {
  description = "The AWS account ID this is being run in"
}

variable aws_region {
  description = "The AWS region. Defaults to us-east-1"
  default     = "us-east-1"
}

variable eks_cluster_oidc_arn {
  description = "The OIDC provider ARN for the cluster you are creating a role in"
}

variable kubernetes_namespace {
  description = "The namespace the service account that will assume this role lives in"
}

variable kubernetes_service_account {
  description = "The name of the service account that will assume this role"
}

variable "role_assume_role_policy" {
  description = "Assume role policy in JSON format. If this is set, aws_account_id, aws_region, eks_cluster_oidc_id, kubernetes_namespace, and kubernetes_service_account will be ignored"
  default     = ""
}

variable "role_tags" {
  description = "Tags for the role"
  default     = {}
}

variable "role_force_detach_policies" {
  description = "Specifies to force detaching any policies the role has before destroying it. Defaults to false."
  default     = "false"
}

variable "role_description" {
  description = "Description for the role"
  default     = ""
}

variable "policy_name" {
  description = "Name for the policy"
}

variable "policy_path" {
  description = "Path in which to create the policy."
  default     = "/"
}

variable "policy_description" {
  description = "Description for the policy"
  default     = ""
}

variable "policy_json" {
  description = "Basically the actual policy in JSON"
}
