output "id" {
  value = aws_launch_template.this.id
}

output "latest_version" {
  value = aws_launch_template.this.latest_version
}

output "name" {
  value = aws_launch_template.this.name
}

output "instance_type" {
  value = aws_launch_template.this.instance_type
}

output "user_data_decoded" {
  value     = var.user_data
  sensitive = true
}
