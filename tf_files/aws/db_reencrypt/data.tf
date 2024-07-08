data "aws_db_instance" "source_db_instance" {
  db_instance_identifier = var.db_instance_identifier
}