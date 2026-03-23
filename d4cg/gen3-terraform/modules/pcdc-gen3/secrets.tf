resource "aws_secretsmanager_secret" "amanuensis_config" {
  name = "${var.vpc_name}-default-amanuensis-config"
}

resource "aws_secretsmanager_secret_version" "amanuensis_config" {
  secret_id     = aws_secretsmanager_secret.amanuensis_config.id
  secret_string = var.amanuensis_config_path != "" ? file(var.amanuensis_config_path) : templatefile("${path.module}/templates/amanuensis-config.tftpl", {
    hostname              = var.hostname
    amanuensis_access_key = var.amanuensis_access_key
    amanuensis_secret_key = var.amanuensis_secret_key
    data_release_bucket   = var.data_release_bucket
  })

}
