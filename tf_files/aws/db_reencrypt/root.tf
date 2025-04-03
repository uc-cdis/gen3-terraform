terraform {
  backend "s3" {
    encrypt = "true"
  }
}

locals {
  snapshot_date       = formatdate("MM-DD-YYYY", timestamp())
  snapshot_identifier = "${var.vpc_name}-${var.cluster_instance_identifier}-reencrypt-${local.snapshot_date}"
  master_password     = var.master_password != "" ? var.master_password : random_password.password.result
}

resource "random_password" "password" {
  length  = var.password_length
  special = false
}

# Aurora Cluster

resource "aws_rds_cluster" "postgresql" {
  cluster_identifier              = "${var.vpc_name}-${var.cluster_identifier}-new"
  engine                          = data.aws_rds_cluster.source_db_instance.engine
  engine_version	                = data.aws_rds_cluster.source_db_instance.engine_version
  db_subnet_group_name	          = data.aws_rds_cluster.source_db_instance.db_subnet_group_name
  vpc_security_group_ids          = data.aws_rds_cluster.source_db_instance.vpc_security_group_ids[*]
  master_username                 = var.master_username
  master_password	                = local.master_password
  storage_encrypted	              = true
  apply_immediately               = true
  engine_mode        	            = var.engine_mode
  skip_final_snapshot	            = false
  final_snapshot_identifier       = "${var.vpc_name}-${var.cluster_instance_identifier}-new-snapshot-${local.snapshot_date}"
  snapshot_identifier             = aws_db_cluster_snapshot.db_snapshot.id
  backup_retention_period         = data.aws_rds_cluster.source_db_instance.backup_retention_period
  preferred_backup_window         = data.aws_rds_cluster.source_db_instance.preferred_backup_window
  db_cluster_parameter_group_name = data.aws_rds_cluster.source_db_instance.db_cluster_parameter_group_name
  kms_key_id                      = var.db_kms_key_id 

  serverlessv2_scaling_configuration {
    max_capacity = var.serverlessv2_scaling_max_capacity
    min_capacity = var.serverlessv2_scaling_min_capacity
  }

  lifecycle {
    ignore_changes = all
  }
}

# Aurora Cluster Instance

resource "aws_rds_cluster_instance" "postgresql" {
  db_subnet_group_name = aws_rds_cluster.postgresql.db_subnet_group_name
  identifier         	 = "${var.vpc_name}-${var.cluster_instance_identifier}-new"
  cluster_identifier 	 = aws_rds_cluster.postgresql.cluster_identifier
  instance_class	     = var.instance_class
  engine             	 = data.aws_rds_cluster.source_db_instance.engine
  engine_version     	 = data.aws_rds_cluster.source_db_instance.engine_version

  lifecycle {
    ignore_changes = all
  }
}

# Create a snapshot of the existing RDS instance
resource "aws_db_cluster_snapshot" "db_snapshot" {
  db_cluster_identifier = data.aws_rds_cluster.source_db_instance.id
  db_cluster_snapshot_identifier = local.snapshot_identifier
  lifecycle {
    ignore_changes = all
  }
}

