terraform {
  backend "s3" {
    encrypt = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  # 1. Build selection rules to select target source tables
  selection_rules = [
    for idx, mapping in var.table_mappings : {
      rule-type = "selection"
      rule-id   = tostring((idx * 2) + 1)
      rule-name = "select-${mapping.source_schema}-${mapping.source_table}"
      object-locator = {
        schema-name = mapping.source_schema
        table-name  = mapping.source_table
      }
      rule-action = "include"
    }
  ]

  # 2. Build transformation rules to rename target tables or schemas
  transformation_rules = flatten([
    for idx, mapping in var.table_mappings : concat(
      # Table rename rule (if target_table is specified)
      mapping.target_table != null ? [{
        rule-type   = "transformation"
        rule-id     = tostring((idx * 2) + 2)
        rule-name   = "rename-table-${mapping.source_table}-to-${mapping.target_table}"
        rule-target = "table"
        object-locator = {
          schema-name = mapping.source_schema
          table-name  = mapping.source_table
        }
        rule-action = "rename"
        value       = mapping.target_table
      }] : [],

      # Schema rename rule (if target_schema is specified)
      mapping.target_schema != null ? [{
        rule-type   = "transformation"
        rule-id     = tostring(1000 + idx)
        rule-name   = "rename-schema-${mapping.source_schema}-to-${mapping.target_schema}"
        rule-target = "schema"
        object-locator = {
          schema-name = mapping.source_schema
        }
        rule-action = "rename"
        value       = mapping.target_schema
      }] : []
    )
  ])

  # Combine into final JSON string
  dms_table_mappings_json = jsonencode({
    rules = concat(local.selection_rules, local.transformation_rules)
  })
}

module "dms" {
  source  = "terraform-aws-modules/dms/aws"
  version = "~> 2.0"

  # Subnet Group
  repl_subnet_group_name        = "${var.name_prefix}-subnet-group"
  repl_subnet_group_description = "DMS Subnet Group for ${var.name_prefix}"
  repl_subnet_group_subnet_ids  = var.subnet_ids

  # Instance Config
  replication_instances = {
    main = {
      replication_instance_class = var.replication_instance_class
      allocated_storage          = 50
      vpc_security_group_ids     = var.vpc_security_group_ids
      publicly_accessible        = false
      multi_az                   = false
    }
  }

  # Source and Target Endpoints
  endpoints = {
    source = {
      endpoint_id   = "${var.name_prefix}-source-endpoint"
      endpoint_type = "source"
      engine_name   = var.engine_name
      server_name   = var.source_config.host
      port          = var.source_config.port
      database_name = var.source_config.db_name
      username      = var.source_config.username
      password      = var.source_config.password
      ssl_mode      = "require"
    }

    target = {
      endpoint_id   = "${var.name_prefix}-target-endpoint"
      endpoint_type = "target"
      engine_name   = var.engine_name
      server_name   = var.target_config.host
      port          = var.target_config.port
      database_name = var.target_config.db_name
      username      = var.target_config.username
      password      = var.target_config.password
      ssl_mode      = "require"
    }
  }

  # Replication Task
  replication_tasks = {
    table_migration = {
      replication_task_id       = "${var.name_prefix}-task"
      migration_type            = var.migration_type
      replication_instance_key  = "main"
      source_endpoint_key       = "source"
      target_endpoint_key       = "target"
      table_mappings            = local.dms_table_mappings_json
      start_replication_task    = true
      replication_task_settings = jsonencode({
        TargetMetadata = {
          TargetMode = "DO_NOTHING" # Preserves existing destination schemas/tables
        }
      })
    }
  }
}
