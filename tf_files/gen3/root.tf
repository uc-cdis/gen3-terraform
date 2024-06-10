locals {
  values = templatefile("${path.module}/values.tftpl", {
      account_id = data.aws_caller_identity.current.account_id
      namespace = var.namespace
      ambassador_enabled = var.ambassador_enabled
      arborist_enabled = var.arborist_enabled
      argo_enabled = var.argo_enabled
      audit_enabled = var.audit_enabled
      audit_service_account = aws_iam_role.audit_role.arn
      aurora_hostname = var.aurora_hostname
      aurora_username = var.aurora_username
      aurora_password = var.aurora_password
      aws-es-proxy_enabled = var.aws-es-proxy_enabled
      dbgap_enabled = var.dbgap_enabled
      dd_enabled = var.dd_enabled
      dictionary_url = var.dictionary_url
      dispatcher_job_number = var.dispatcher_job_number
      es_endpoint = var.es_endpoint
      es_user_key = var.es_user_key
      es_user_secret =  var.es_user_secret
      fence_config = var.fence_config_path != "" ? indent(4, file(var.fence_config_path)) : templatefile("${path.module}/fence-config.tftpl", {
        hostname             = var.hostname
        google_client_id     = var.google_client_id
        google_client_secret = var.google_client_secret
        fence_access_key     = var.fence_access_key
        fence_secret_key     = var.fence_secret_key
        upload_buckety       = var.upload_bucket
      })
      fence_enabled = var.fence_enabled
      fence_service_account = aws_iam_role.fence_role.arn
      gitops_file = var.gitops_path != "" ? indent(4, file(var.gitops_path)) : "{}"
      guppy_enabled = var.guppy_enabled
      hatchery_enabled = var.hatchery_enabled
      hatchery_service_account = aws_iam_role.hatchery_role.arn
      hostname = var.hostname
      indexd_enabled = var.indexd_enabled
      indexd_prefix = var.indexd_prefix
      ingress_enabled = var.ingress_enabled
      manifestservice_enabled = var.manifestservice_enabled
      metadata_enabled = var.metadata_enabled
      netpolicy_enabled = var.netpolicy_enabled
      peregrine_enabled = var.peregrine_enabled
      pidgin_enabled = var.pidgin_enabled
      portal_enabled = var.portal_enabled
      public_datasets = var.public_datasets
      requestor_enabled = var.requestor_enabled
      revproxy_arn = var.revproxy_arn
      revproxy_enabled = var.revproxy_enabled
      sheepdog_enabled = var.sheepdog_enabled
      slack_send_dbgap = var.slack_send_dbgap
      slack_webhook = var.slack_webhook
      ssjdispatcher_enabled = var.ssjdispatcher_enabled
      tier_access_level = var.tier_access_level
      tier_access_limit = var.tier_access_limit
      usersync_enabled = var.usersync_enabled
      usersync_schedule = var.usersync_schedule
      user_yaml = var.useryaml_path != "" ? indent(4, file(var.useryaml_path)) : "{}"
      useryaml_s3_path = var.useryaml_s3_path
      vpc_name = var.vpc_name
      wts_enabled = var.wts_enabled
    })
}

resource "helm_release" "gen3" {
  count      = var.deploy_gen3 ? 1 : 0
  name       = var.namespace
  repository = "http://helm.gen3.org"
  chart      = "gen3"
  namespace  = var.namespace
  create_namespace = true
  wait = false

  values = [ local.values ]

}

resource "local_file" "values" {
  count    = var.deploy_gen3 ? 1 : 0
  filename = "values.yaml"
  content  = local.values
}

resource "aws_secretsmanager_secret" "secret" {
  name = "${var.vpc_name}_${var.namespace}-values"
}

resource "aws_secretsmanager_secret_version" "secret" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = local.values
}
