
output "identifier" {
  value = aws_rds_cluster_instance.postgresql.identifier
}


output "cluster_identifier" {
  value = aws_rds_cluster.postgresql.cluster_identifier
}
