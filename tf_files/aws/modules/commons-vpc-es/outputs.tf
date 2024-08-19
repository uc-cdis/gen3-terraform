output "kibana_endpoint" {
  value = aws_elasticsearch_domain.gen3_metadata.kibana_endpoint
}

output "es_endpoint" {
  value = aws_elasticsearch_domain.gen3_metadata.endpoint
}

output "es_arn" {
  value = aws_elasticsearch_domain.gen3_metadata.arn
}
