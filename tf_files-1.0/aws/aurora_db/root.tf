terraform {
  backend "s3" {
    encrypt = "true"
  }
}

locals {
  sa_name           = "${var.service}-sa"
  sa_namespace      = var.namespace
  eks_oidc_issuer   = trimprefix(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://")
  database_name     = var.database_name != "" ? var.database_name : "${var.service}_${var.namespace}"
  database_username = var.username != "" ? var.username : "${var.service}_${var.namespace}"
  database_password = var.password != "" ? var.password : random_password.db_password[0].result
}

module "secrets_manager" {
  count       = var.secrets_manager_enabled ? 1 : 0
  source	    = "../modules/secrets_manager"
  vpc_name    = var.vpc_name
  secret	    = templatefile("${path.module}/secrets_manager.tftpl", {
    hostname = data.aws_db_instance.database.address
    database = local.database_name
    username = local.database_username
    password = local.database_password
  })
  secret_name = "${var.vpc_name}-${var.service}-creds"

  depends_on = [ null_resource.user_setup ]
}

resource "aws_iam_policy" "secrets_manager_policy" {
  count       = var.secrets_manager_enabled ? 1 : 0
  name        = "${var.vpc_name}-${var.service}-${var.namespace}-creds-access-policy"
  description = "Policy for ${var.vpc_name}-${var.service} to access secrets manager"
  policy      = data.aws_iam_policy_document.policy.json
}

resource "aws_iam_role" "role" {
  count              = var.secrets_manager_enabled ? var.role != "" ? 0 : 1 : 0
  name               = "${var.vpc_name}-${var.service}-${var.namespace}-creds-access-role"
  assume_role_policy = data.aws_iam_policy_document.sa_policy.json
}

resource "aws_iam_role_policy_attachment" "new_attach" {
  count      = var.secrets_manager_enabled ? 1 : 0
  role       = var.role != "" ? var.role : aws_iam_role.role[0].name
  policy_arn = aws_iam_policy.secrets_manager_policy[0].arn
}

resource "random_password" "db_password" {
  count            = var.password != "" ? 0 : 1
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "null_resource" "db_setup" {
    provisioner "local-exec" {
        command = "psql -h ${data.aws_db_instance.database.address} -U ${var.admin_database_username} -d ${var.admin_database_name} -c \"CREATE DATABASE \\\"${local.database_name}\\\";\""
        environment = {
          # for instance, postgres would need the password here:
          PGPASSWORD = var.admin_database_password != "" ? var.admin_database_password : data.aws_secretsmanager_secret_version.aurora-master-password.secret_string
        }
      on_failure = continue
    }
}

resource "null_resource" "user_setup" {

    provisioner "local-exec" {
        command = "psql -h ${data.aws_db_instance.database.address} -U ${var.admin_database_username} -d ${var.admin_database_name} -c \"${templatefile("${path.module}/db_setup.tftpl", {
          username  = local.database_username
          database  = local.database_name
          password  = local.database_password
        })}\""
        environment = {
          # for instance, postgres would need the password here:
          PGPASSWORD = var.admin_database_password != "" ? var.admin_database_password : data.aws_secretsmanager_secret_version.aurora-master-password.secret_string
        }
    }

    triggers = {
        username = local.database_username
        database = local.database_name
        password = local.database_password
    }

    depends_on = [ null_resource.db_setup ]
}
