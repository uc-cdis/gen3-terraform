terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}


locals {
  snapshot_date       = formatdate("MM-DD-YYYY", timestamp())
  snapshot_identifier = "reencrypt-${local.snapshot_date}"
}

resource "random_password" "password" {
  length  = var.password_length
  special = false
}

# Aurora Cluster

resource "aws_rds_cluster" "postgresql" {
  cluster_identifier              = "${var.vpc_name}-${var.cluster_identifier}-new"
  engine                          = data.aws_db_instance.source_db_instance.engine
  engine_version	                = data.aws_db_instance.source_db_instance.engine_version
  db_subnet_group_name	          = data.aws_db_instance.source_db_instance.db_subnet_group_name
  vpc_security_group_ids          = [data.aws_security_group.private.id]
  master_username                 = var.master_username
  master_password	                = random_password.password.result
  storage_encrypted	              = true
  apply_immediately               = true
  engine_mode        	            = var.engine_mode
  skip_final_snapshot	            = false
  final_snapshot_identifier       = "${var.vpc_name}-new-snapshot"
  backup_retention_period         = data.aws_db_instance.source_db_instance.backup_retention_period
  preferred_backup_window         = data.aws_db_instance.source_db_instance.preferred_backup_window
  db_cluster_parameter_group_name = data.aws_db_instance.source_db_instance.parameter_group_name
  kms_key_id                      = var.db_kms_key_id 

  serverlessv2_scaling_configuration {
    max_capacity = var.serverlessv2_scaling_max_capacity
    min_capacity = var.serverlessv2_scaling_min_capacity
  }
}

# Aurora Cluster Instance

resource "aws_rds_cluster_instance" "postgresql" {
  db_subnet_group_name = aws_rds_cluster.postgresql.db_subnet_group_name
  identifier         	 = "${var.vpc_name}-${var.cluster_instance_identifier}-new"
  cluster_identifier 	 = aws_rds_cluster.postgresql.id
  instance_class	     = data.aws_db_instance.source_db_instance.instance_class
  engine             	 = data.aws_db_instance.source_db_instance.engine
  engine_version     	 = data.aws_db_instance.source_db_instance.engine_version
  kms_key_id           = var.db_kms_key_id
}

# Create a snapshot of the existing RDS instance
resource "aws_db_snapshot" "db_snapshot" {
  db_instance_identifier = var.db_instance_identifier
  db_snapshot_identifier = local.snapshot_identifier
}

# Copy the snapshot and re-encrypt with the new KMS key
resource "aws_db_snapshot_copy" "db_snapshot_copy" {
  depends_on                    = [aws_db_snapshot.db_snapshot]
  source_db_snapshot_identifier = aws_db_snapshot.db_snapshot.id
  target_db_snapshot_identifier = "${local.snapshot_identifier}-copy"
  kms_key_id                    = var.db_kms_key_id
}