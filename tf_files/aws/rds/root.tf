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

module "aws_rds" {
  source                                             = "../modules/rds/"
  rds_instance_allocated_storage                     = var.rds_instance_allocated_storage
  rds_instance_allow_major_version_upgrade           = var.rds_instance_allow_major_version_upgrade
  rds_instance_apply_immediately                     = var.rds_instance_apply_immediately
  rds_instance_auto_minor_version_upgrade            = var.rds_instance_auto_minor_version_upgrade
  rds_instance_availability_zone                     = var.rds_instance_availability_zone
  rds_instance_backup_retention_period               = var.rds_instance_backup_retention_period
  rds_instance_backup_window                         = var.rds_instance_backup_window
  rds_instance_character_set_name                    = var.rds_instance_character_set_name
  rds_instance_copy_tags_to_snapshot                 = var.rds_instance_copy_tags_to_snapshot
  rds_instance_create_monitoring_role                = var.rds_instance_create_monitoring_role
  rds_instance_create                                = var.rds_instance_create
  rds_instance_db_subnet_group_name                  = var.rds_instance_db_subnet_group_name
  rds_instance_deletion_protection                   = var.rds_instance_deletion_protection
  rds_instance_enabled_cloudwatch_logs_exports       = var.rds_instance_enabled_cloudwatch_logs_exports
  rds_instance_engine                                = var.rds_instance_engine
  rds_instance_engine_version                        = var.rds_instance_engine_version
  rds_instance_final_snapshot_identifier             = var.rds_instance_final_snapshot_identifier
  rds_instance_iam_database_authentication_enabled   = var.rds_instance_iam_database_authentication_enabled
  rds_instance_identifier                            = var.rds_instance_identifier
  rds_instance_instance_class                        = var.rds_instance_instance_class
  rds_instance_iops                                  = var.rds_instance_iops
  rds_instance_throughput                            = var.rds_instance_throughput
  rds_instance_kms_key_id                            = var.rds_instance_kms_key_id
  rds_instance_license_model                         = var.rds_instance_license_model
  rds_instance_maintenance_window                    = var.rds_instance_maintenance_window
  rds_instance_max_allocated_storage                 = var.rds_instance_max_allocated_storage
  rds_instance_monitoring_interval                   = var.rds_instance_monitoring_interval
  rds_instance_monitoring_role_arn                   = var.rds_instance_monitoring_role_arn
  rds_instance_monitoring_role_name                  = var.rds_instance_monitoring_role_name
  rds_instance_multi_az                              = var.rds_instance_multi_az
  rds_instance_name                                  = var.rds_instance_name
  rds_instance_option_group_name                     = var.rds_instance_option_group_name
  rds_instance_parameter_group_name                  = var.rds_instance_parameter_group_name
  rds_instance_password                              = var.rds_instance_password
  rds_instance_performance_insights_enabled          = var.rds_instance_performance_insights_enabled
  rds_instance_performance_insights_retention_period = var.rds_instance_performance_insights_retention_period
  rds_instance_port                                  = var.rds_instance_port
  rds_instance_publicly_accessible                   = var.rds_instance_publicly_accessible
  rds_instance_replicate_source_db                   = var.rds_instance_replicate_source_db
  rds_instance_skip_final_snapshot                   = var.rds_instance_skip_final_snapshot
  rds_instance_snapshot_identifier                   = var.rds_instance_snapshot_identifier
  rds_instance_storage_encrypted                     = var.rds_instance_storage_encrypted
  rds_instance_storage_type                          = var.rds_instance_storage_type
  rds_instance_tags                                  = var.rds_instance_tags
  rds_instance_timezone                              = var.rds_instance_timezone
  rds_instance_username                              = var.rds_instance_username
  rds_instance_vpc_security_group_ids                = var.rds_instance_vpc_security_group_ids
  rds_instance_backup_enabled                        = var.rds_instance_backup_enabled
  rds_instance_backup_kms_key                        = var.rds_instance_backup_kms_key
  rds_instance_backup_bucket_name                    = var.rds_instance_backup_bucket_name
}
