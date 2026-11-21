variable "name_prefix" {
  description = "Prefix for migration resources"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs in Target Account for DMS instance"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "Security group IDs for DMS instance in Target Account"
  type        = list(string)
}

variable "target_vpc_cidr" {
  description = "CIDR block of Target VPC (used for Source RDS ingress rule)"
  type        = string
}

variable "source_rds_security_group_id" {
  description = "Security Group ID of the Source RDS Cluster in Account A"
  type        = string
}

variable "source_config" {
  description = "Source RDS admin credentials and host"
  type = object({
    host     = string
    port     = number
    db_name  = string
    username = string
    password = string
  })
  sensitive = true
}

variable "target_config" {
  description = "Target RDS admin credentials and host"
  type = object({
    host     = string
    port     = number
    db_name  = string
    username = string
    password = string
  })
  sensitive = true
}

variable "table_mappings" {
  description = "List of table mapping configurations with optional renames"
  type = list(object({
    source_schema = string
    source_table  = string
    target_schema = optional(string) # Defaults to source_schema if null
    target_table  = optional(string) # Defaults to source_table if null
  }))
}