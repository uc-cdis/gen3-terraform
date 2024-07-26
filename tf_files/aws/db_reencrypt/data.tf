data "aws_rds_cluster" "source_db_instance" {
  cluster_identifier = var.db_instance_identifier
}