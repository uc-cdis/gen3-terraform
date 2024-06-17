resource "aws_secretsmanager_secret" "secret" {
  name = "${var.vpc_name}_${var.namespace}-values"
}

resource "aws_secretsmanager_secret_version" "secret" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = local.values
}

resource "aws_secretsmanager_secret" "fence_config" {
  name = "${var.vpc_name}_${var.namespace}-fence-config"
}

resource "aws_secretsmanager_secret_version" "fence_config" {
  secret_id     = aws_secretsmanager_secret.fence_config.id
  secret_string = var.fence_config_path != "" ? file(var.fence_config_path) : templatefile("${path.module}/fence-config.tftpl", {
        hostname             = var.hostname
        google_client_id     = var.google_client_id
        google_client_secret = var.google_client_secret
        fence_access_key     = var.fence_access_key
        fence_secret_key     = var.fence_secret_key
        upload_bucket       = var.upload_bucket
      })
}

