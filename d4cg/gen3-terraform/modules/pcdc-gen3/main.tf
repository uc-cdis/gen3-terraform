module "gen3" {
  source = "git::github.com/uc-cdis/gen3-terraform.git//tf_files/gen3?ref=master"

  vpc_name                   = var.vpc_name
  aurora_username            = var.aurora_username
  aurora_hostname            = var.aurora_hostname
  aurora_password            = var.aurora_password
  dictionary_url             = var.dictionary_url
  es_endpoint                = var.es_endpoint
  hostname                   = var.hostname
  cluster_endpoint           = var.cluster_endpoint
  cluster_ca_cert            = var.cluster_ca_cert
  cluster_name               = var.cluster_name
  oidc_provider_arn          = var.oidc_provider_arn
  fence_access_key           = var.fence_access_key
  fence_secret_key           = var.fence_secret_key
  upload_bucket              = var.upload_bucket
  revproxy_arn               = var.revproxy_arn
  deploy_external_secrets    = var.deploy_external_secrets
  useryaml_s3_path           = var.useryaml_s3_path
  deploy_gen3                = var.deploy_gen3
  create_dbs                 = var.create_dbs
  cognito_discovery_url      = var.cognito_discovery_url
  cognito_client_id          = var.cognito_client_id
  cognito_client_secret      = var.cognito_client_secret
}
