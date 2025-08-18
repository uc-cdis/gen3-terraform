locals {
  values = templatefile("${path.module}/templates/values.tftpl", {
      account_id = data.aws_caller_identity.current.account_id
      namespace = var.namespace
      ambassador_enabled = var.ambassador_enabled
      arborist_enabled = var.arborist_enabled
      argo_enabled = var.argo_enabled
      audit_enabled = var.audit_enabled
      audit_service_account = aws_iam_role.audit-role[0].arn
      aurora_hostname = var.aurora_hostname
      aurora_username = var.aurora_username
      aurora_password = var.aurora_password
      aws-es-proxy_enabled = var.aws-es-proxy_enabled
      dbgap_enabled = var.dbgap_enabled
      dd_enabled = var.dd_enabled
      external_secrets_operator_iam_role = var.deploy_external_secrets ? aws_iam_role.external-secrets-role[0].arn : null
      deploy_grafana = var.deploy_grafana
      deploy_s3_mountpoint = var.deploy_s3_mountpoint
      dicom-server_enabled = var.dicom-server_enabled
      dicom-viewer_enabled = var.dicom-viewer_enabled
      dictionary_url = var.dictionary_url
      dispatcher_job_number = var.dispatcher_job_number
      es_endpoint = var.es_endpoint
      es_secret_name = aws_secretsmanager_secret.es_user_creds.name
      fence_config_secret_name = aws_secretsmanager_secret.fence_config.name
      fence_enabled = var.fence_enabled
      fence_jwt_keys = aws_secretsmanager_secret.fence-jwt-keys.name
      fence_service_account = var.fence_enabled ? aws_iam_role.fence-role[0].arn : null
      frontend_root = var.gen3ff_enabled ? "gen3ff" : "portal"
      gitops_file = var.gitops_path != "" ? indent(4, file(var.gitops_path)) : "{}"
      gen3ff_enabled = var.gen3ff_enabled
      gen3ff_repo = var.gen3ff_repo
      gen3ff_tag = var.gen3ff_tag
      guppy_enabled = var.guppy_enabled
      hatchery_enabled = var.hatchery_enabled
      hatchery_service_account = aws_iam_role.hatchery-role[0].arn
      hostname = var.hostname
      indexd_enabled = var.indexd_enabled
      indexd_prefix = var.indexd_prefix
      ingress_enabled = var.ingress_enabled
      manifestservice_enabled = var.manifestservice_enabled
      manifestservice_service_account = var.manifestservice_enabled ? aws_iam_role.manifestservice-role[0].arn : null
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
      sower_enabled = var.sower_enabled
      tier_access_level = var.tier_access_level
      tier_access_limit = var.tier_access_limit
      usersync_enabled = var.usersync_enabled
      usersync_schedule = var.usersync_schedule
      useryaml_s3_path = var.useryaml_s3_path
      vpc_name = var.vpc_name
      waf_arn = var.waf_arn
      wts_enabled = var.wts_enabled
    })
}

resource "helm_release" "gen3" {
  count      = var.deploy_gen3 ? 1 : 0
  name       = "gen3-${var.namespace}"
  repository = "https://helm.gen3.org"
  chart      = "gen3"
  namespace  = var.namespace
  create_namespace = true
  wait = false

  values = [ local.values ]

}

resource "local_file" "values" {
  filename = "./gitops-repo/${var.vpc_name}/${var.hostname}/values.yaml"
  content  = local.values
  depends_on = [null_resource.config_setup, helm_release.gen3]
}

resource "local_file" "user_yaml_workflow" {
  filename = "./users-repo/.github/workflows/user-yaml-push.yaml"
  content  = templatefile("${path.module}/templates/user-yaml-push.tftpl", {
    useryaml_s3_path = var.useryaml_s3_path
  })
  depends_on = [null_resource.config_setup, helm_release.gen3]
}

resource "local_file" "cluster_values" {
  filename = "./gitops-repo/${var.vpc_name}/cluster-level-resources/cluster-values.yaml"
  content  = templatefile("${path.module}/templates/cluster-values.tftpl", {
    vpc_name       = var.vpc_name,
    account_number = data.aws_caller_identity.current.account_id
  })
  depends_on = [null_resource.config_setup, helm_release.gen3]
}

resource "local_file" "app_yaml" {
  filename = "./gitops-repo/${var.vpc_name}/${var.hostname}/app.yaml"
  content  = templatefile("${path.module}/templates/app.tftpl", {
    vpc_name  = var.vpc_name,
    hostname  = var.hostname,
    namespace = var.namespace
  })
  depends_on = [null_resource.config_setup, helm_release.gen3]
}

resource "local_file" "cluster_app_yaml" {
  filename = "./gitops-repo/${var.vpc_name}/cluster-level-resources/app.yaml"
  content  = templatefile("${path.module}/templates/cluster-app.tftpl", {
    vpc_name  = var.vpc_name
  })
  depends_on = [null_resource.config_setup, helm_release.gen3]
}

resource "null_resource" "config_setup" {

  provisioner "local-exec" {
    command = "cp -rf ${path.module}/gitops-repo ./; cp -rf ${path.module}/users-repo ./; mkdir -p ./gitops-repo/${var.vpc_name}/${var.hostname}"
  }

}

resource "tls_private_key" "fence-jwt-keys" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
