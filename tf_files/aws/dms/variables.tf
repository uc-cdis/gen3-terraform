variable "name_prefix" {
  description = "Prefix for all DMS resource names"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the DMS replication instance"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "Security group IDs for the DMS replication instance"
  type        = list(string)
}

variable "replication_instance_class" {
  description = "Compute size for DMS instance"
  type        = string
  default     = "dms.t3.medium"
}

variable "engine_name" {
  description = "Database engine type (e.g. postgres, mysql, aurora-postgresql)"
  type        = string
}

# Source Endpoint Config
variable "source_config" {
  description = "Source database connection settings"
  type = object({
    host     = string
    port     = number
    db_name  = string
    username = string
    password = string
  })
  sensitive = true
}

# Target Endpoint Config
variable "target_config" {
  description = "Target database connection settings"
  type = object({
    host     = string
    port     = number
    db_name  = string
    username = string
    password = string
  })
  sensitive = true
}

# Migration Task Type
variable "migration_type" {
  description = "full-load | cdc | full-load-and-cdc"
  type        = string
  default     = "full-load"
}

# Table Mapping Definitions
variable "table_mappings" {
  description = "List of table mappings with optional table and schema renames"
  type = list(object({
    source_schema = string
    source_table  = string
    target_table  = optional(string) # Set if table name changes
    target_schema = optional(string) # Set if schema name changes
  }))
}
