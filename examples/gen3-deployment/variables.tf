variable "vpc_name" {
  type        = string
  description = "Name of the VPC; used to identify most resources created within the module."
}

#fixme
variable "account_number" {
  type        = string
  description = "AWS account number where resources will be created. If not set, falls back to data.aws_caller_identity.current.account_id."
  default     = null
}

variable "aws_region" {
  type        = string
  description = "AWS region where the resources will be created (e.g. us-east-1)."
}

variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace your Gen3 deployment will use. Default is good for first time deployments. If you want another deployment in the same cluster, copy paste the gen3 module block, create a new namespace local variable or manually update the namespace within the second instance of the module"
  default     = "default"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones to use (e.g. [\"us-east-1a\", \"us-east-1c\", \"us-east-1d\"])."
}

variable "hostname" {
  type        = string
  description = "Hostname for your Gen3 deployment. If you are creating another instance of the gen3 module set the hostname in it accordingly."
}

variable "es_linked_role" {
  type        = bool
  description = "Whether to create the Elasticsearch service-linked role (can only be created once per account)."
  default     = false
}

variable "revproxy_arn" {
  type        = string
  description = "ARN of the ACM certificate used by the reverse proxy."
}

variable "create_gitops_infra" {
  type        = bool
  description = "Whether to create users/buckets needed for user.yaml GitOps management."
  default     = true
}

variable "user_yaml_bucket_name" {
  type        = string
  description = "Name of the S3 bucket where the user.yaml file will be stored. Notice this will be created by terraform, so you don't need to create it beforehand."
}

variable "ssh_key" {
  type        = string
  description = "Name of the SSH key used to access the nodes in the EKS cluster."
  default     = ""
}

variable "default_tags" {
  type        = map(string)
  description = "Tags to apply to all resources created by this module. If empty, a default Environment tag will be set from vpc_name."
  default     = {}
}
