variable "vpc_name" {}

variable "db_instance_identifier" {
  default = ""
}

variable "db_kms_key_id" {
  default = ""
}

variable "engine_mode" {
  type        = string
  description = "use provisioned for Serverless v2 RDS cluster"
  default     = "provisioned"
}

variable "cluster_identifier" {
  description = "Cluster Identifier"
  type        = string
  default     = "aurora-cluster"
}

variable "cluster_instance_identifier" {
  description = "Cluster Instance Identifier"
  type        = string
  default     = "aurora-cluster-instance"
}

variable "serverlessv2_scaling_min_capacity" {
  type        = string
  description = "Serverless v2 RDS cluster minimum scaling capacity in ACUs"
  default     = "0.5"
}

variable "serverlessv2_scaling_max_capacity" {
  type        = string
  description = "Serverless v2 RDS cluster maximum scaling capacity in ACUs"
  default     = "10.0"
}

variable "master_username" {
  description = "Master DB username"
  type        = string
  default     = "postgres"
}

variable "storage_encrypted" {
  description = "Specifies whether storage encryption is enabled"
  type        = bool
  default     = true
}

variable "engine_mode" {
  type        = string
  description = "use provisioned for Serverless v2 RDS cluster"
  default     = "provisioned"
}

variable "password_length" {
  type        = number
  description = "The length of the password string"
  default     = 12
}