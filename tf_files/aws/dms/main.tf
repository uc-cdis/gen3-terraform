terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.22"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# -----------------------------------------------------------------------------
# 1. RANDOM PASSWORD GENERATOR
# -----------------------------------------------------------------------------
resource "random_password" "dms_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# -----------------------------------------------------------------------------
# 2. POSTGRESQL PROVIDERS (Source & Target)
# -----------------------------------------------------------------------------
provider "postgresql" {
  alias           = "source"
  host            = var.source_config.host
  port            = var.source_config.port
  database        = var.source_config.db_name
  username        = var.source_config.username
  password        = var.source_config.password
  sslmode         = "require"
  connect_timeout = 15
}

provider "postgresql" {
  alias           = "target"
  host            = var.target_config.host
  port            = var.target_config.port
  database        = var.target_config.db_name
  username        = var.target_config.username
  password        = var.target_config.password
  sslmode         = "require"
  connect_timeout = 15
}

# -----------------------------------------------------------------------------
# 3. TEMPORARY INGRESS RULE ON SOURCE RDS
# -----------------------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "allow_dms_source_psql" {
  security_group_id = var.source_rds_security_group_id
  description       = "Temporary ingress for DMS migration from Target VPC CIDR"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = var.target_vpc_cidr
}

# -----------------------------------------------------------------------------
# 4. DYNAMIC POSTGRES ROLES & PERMISSIONS
# -----------------------------------------------------------------------------
locals {
  # Normalize schema and table names
  normalized_mappings = [
    for m in var.table_mappings : {
      source_schema = m.source_schema
      source_table  = m.source_table
      target_schema = coalesce(m.target_schema, m.source_schema)
      target_table  = coalesce(m.target_table, m.source_table)
    }
  ]

  source_tables_map = { for m in local.normalized_mappings : "${m.source_schema}.${m.source_table}" => m }
  target_tables_map = { for m in local.normalized_mappings : "${m.target_schema}.${m.target_table}" => m }

  source_schemas = toset([for m in local.normalized_mappings : m.source_schema])
  target_schemas = toset([for m in local.normalized_mappings : m.target_schema])
}

# --- SOURCE DB: READ-ONLY ACCESS ---
resource "postgresql_role" "dms_source_role" {
  provider = postgresql.source
  name     = "${var.name_prefix}_dms_reader"
  login    = true
  password = random_password.dms_password.result
}

resource "postgresql_grant" "source_schema_usage" {
  provider    = postgresql.source
  for_each    = local.source_schemas
  database    = var.source_config.db_name
  role        = postgresql_role.dms_source_role.name
  schema      = each.value
  object_type = "schema"
  privileges  = ["USAGE"]
}

resource "postgresql_grant" "source_table_read" {
  provider    = postgresql.source
  for_each    = local.source_tables_map
  database    = var.source_config.db_name
  role        = postgresql_role.dms_source_role.name
  schema      = each.value.source_schema
  object_type = "table"
  objects     = [each.value.source_table]
  privileges  = ["SELECT"]
}

# --- TARGET DB: READ/WRITE ACCESS ---
resource "postgresql_role" "dms_target_role" {
  provider = postgresql.target
  name     = "${var.name_prefix}_dms_writer"
  login    = true
  password = random_password.dms_password.result
}

resource "postgresql_grant" "target_schema_permissions" {
  provider    = postgresql.target
  for_each    = local.target_schemas
  database    = var.target_config.db_name
  role        = postgresql_role.dms_target_role.name
  schema      = each.value
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]
}

resource "postgresql_grant" "target_table_write" {
  provider    = postgresql.target
  for_each    = local.target_tables_map
  database    = var.target_config.db_name
  role        = postgresql_role.dms_target_role.name
  schema      = each.value.target_schema
  object_type = "table"
  objects     = [each.value.target_table]
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER"]
}

# -----------------------------------------------------------------------------
# 5. AWS DMS MODULE & TRANSFORMATION RULES
# -----------------------------------------------------------------------------
locals {
  # Generate inclusion rules
  selection_rules = [
    for idx, mapping in local.normalized_mappings : {
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

  # Generate table/schema rename transformation rules
  transformation_rules = flatten([
    for idx, mapping in local.normalized_mappings : concat(
      mapping.source_table != mapping.target_table ? [{
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

      mapping.source_schema != mapping.target_schema ? [{
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

  dms_table_mappings_json = jsonencode({
    rules = concat(local.selection_rules, local.transformation_rules)
  })
}

module "dms" {
  source  = "terraform-aws-modules/dms/aws"
  version = "~> 2.0"

  repl_subnet_group_name       = "${var.name_prefix}-subnet-group"
  repl_subnet_group_subnet_ids = var.subnet_ids

  replication_instances = {
    main = {
      replication_instance_class = "dms.t3.medium"
      allocated_storage          = 50
      vpc_security_group_ids     = var.vpc_security_group_ids
      publicly_accessible        = false
    }
  }

  endpoints = {
    source = {
      endpoint_id   = "${var.name_prefix}-src"
      endpoint_type = "source"
      engine_name   = "postgres"
      server_name   = var.source_config.host
      port          = var.source_config.port
      database_name = var.source_config.db_name
      username      = postgresql_role.dms_source_role.name
      password      = random_password.dms_password.result
      ssl_mode      = "require"
    }

    target = {
      endpoint_id   = "${var.name_prefix}-tgt"
      endpoint_type = "target"
      engine_name   = "postgres"
      server_name   = var.target_config.host
      port          = var.target_config.port
      database_name = var.target_config.db_name
      username      = postgresql_role.dms_target_role.name
      password      = random_password.dms_password.result
      ssl_mode      = "require"
    }
  }

  replication_tasks = {
    migration_task = {
      replication_task_id      = "${var.name_prefix}-task"
      migration_type           = "full-load"
      replication_instance_key = "main"
      source_endpoint_key      = "source"
      target_endpoint_key      = "target"
      table_mappings           = local.dms_table_mappings_json
      start_replication_task   = true
      replication_task_settings = jsonencode({
        TargetMetadata = {
          TargetMode = "DO_NOTHING"
        }
      })
    }
  }
}