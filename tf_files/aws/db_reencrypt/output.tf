
output "identifier" {
  value = aws_rds_cluster_instance.postgresql.0.identifier
}


output "cluster_identifier" {
  value = aws_rds_cluster.postgresql.0.cluster_identifier
}
