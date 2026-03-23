variable "aurora_username" {
  description = "aurora username"
  default = ""
}

variable "aurora_hostname" {
  description = "aurora hostname"
  default = ""
}

variable "aurora_password" {
  description = "aurora password"
  default = ""
}

variable "dictionary_url" {
  description = "URL to the data dictionary"
  default     = ""
}

variable "deploy_external_secrets" {
  description = "Deploy external secrets"
  type        = bool
  default     = false
}

variable "es_endpoint" {
  description = "Elasticsearch endpoint"
  default     = ""
}

variable "hostname" {
  description = "hostname of the commons"
  default = ""
}

variable "revproxy_arn" {
  description = "ARN for the revproxy cert in ACM"
  default     = ""
}

variable "useryaml_s3_path" {
  description = "S3 path to the user.yaml file"
  default     = "s3://cdis-gen3-users/dev/user.yaml"
}

variable "vpc_name" {
  description = "Name of the VPC"
  default     = ""
}

variable "cluster_endpoint" {
 default = ""
}

variable "cluster_ca_cert" {
  default = ""
}

variable "cluster_name" {
  default = ""
}

variable "oidc_provider_arn" {
  default = ""
}

variable "fence_access_key" {
  default = ""
}

variable "fence_secret_key" {
  default = ""
}

variable "upload_bucket" {
  default = ""
}

variable "deploy_gen3" {
  default = false
}

variable "create_dbs" {
  description = "Whether to create databases or not. Requires connectivity to RDS cluster."
  default = false
}

variable "cognito_discovery_url" {
  default = ""
}

variable "cognito_client_id" {
  default = ""
}

variable "cognito_client_secret" {
  default = ""
}

variable "amanuensis_access_key" {
  default = ""
}

variable "amanuensis_secret_key" {
  default = ""
}

variable "data_release_bucket" {
  default = ""
}

variable "amanuensis_config_path" {
  default = ""
}

variable "data-release-bucket_name" {
  description = "Name of the bucket used for data release, used by amanuensis to export data from the commons"
  default     = ""
}