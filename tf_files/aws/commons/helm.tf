module "gen3_deployment" {
  source = "../../gen3"
  count  = var.deploy_gen3 && var.deploy_aurora ? 1 : 0

  aurora_password         = module.aurora.0.aurora_cluster_master_password
  aurora_hostname         = module.aurora.0.aurora_cluster_writer_endpoint
  aurora_username         = module.aurora.0.aurora_cluster_master_username

  cluster_endpoint        = module.eks.0.cluster_endpoint
  cluster_ca_cert         = module.eks.0.cluster_certificate_authority_data
  cluster_name            = module.eks.0.cluster_name
  ambassador_enabled      = var.ambassador_enabled
  arborist_enabled        = var.arborist_enabled
  argo_enabled            = var.argo_enabled
  audit_enabled           = var.audit_enabled
  aws-es-proxy_enabled    = var.aws-es-proxy_enabled
  dbgap_enabled           = var.dbgap_enabled
  dd_enabled              = var.dd_enabled
  dictionary_url          = var.dictionary_url
  dispatcher_job_number   = var.dispatcher_job_number
  fence_enabled           = var.fence_enabled
  guppy_enabled           = var.guppy_enabled
  hatchery_enabled        = var.hatchery_enabled
  hostname                = var.hostname
  indexd_enabled          = var.indexd_enabled
  indexd_prefix           = var.indexd_prefix
  ingress_enabled         = var.ingress_enabled
  manifestservice_enabled = var.manifestservice_enabled
  metadata_enabled        = var.metadata_enabled
  netpolicy_enabled       = var.netpolicy_enabled
  peregrine_enabled       = var.peregrine_enabled
  pidgin_enabled          = var.pidgin_enabled
  portal_enabled          = var.portal_enabled
  public_datasets         = var.public_datasets
  requestor_enabled       = var.requestor_enabled
  revproxy_arn            = var.revproxy_arn
  revproxy_enabled        = var.revproxy_enabled
  sheepdog_enabled        = var.sheepdog_enabled
  slack_send_dbgap        = var.slack_send_dbgap
  slack_webhook           = var.slack_webhook
  ssjdispatcher_enabled   = var.ssjdispatcher_enabled
  tier_access_level       = var.tier_access_level
  tier_access_limit       = var.tier_access_limit
  usersync_enabled        = var.usersync_enabled
  usersync_schedule       = var.usersync_schedule
  useryaml_s3_path        = var.useryaml_s3_path
  wts_enabled             = var.wts_enabled
  fence_config_path       = var.fence_config_path
  useryaml_path           = var.useryaml_path
  gitops_path             = var.gitops_path
  google_client_id        = var.google_client_id
  google_client_secret    = var.google_client_secret
  fence_access_key        = var.fence_access_key
  fence_secret_key        = var.fence_secret_key
  upload_bucket           = var.upload_bucket
  namespace               = var.namespace
}


# Deploy ArgoCD 
resource helm_release "argocd" {
  count            = var.k8s_bootstrap_resources && var.deploy_argocd ? 1 : 0
  name             = "argocd"
  chart            = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  version          = var.argocd_version
  namespace        = "argocd"
  create_namespace = true

  values = [
    <<-EOT
    server.basehref: "/argocd/"
    EOT
  ]
}

# Deploy External Secrets Operator
resource helm_release "external-secrets" {
  count      = var.k8s_bootstrap_resources && var.deploy_external_secrets_operator ? 1 : 0
  name       = "external-secrets"
  chart      = "external-secrets"
  repository = "https://charts.external-secrets.io"
  version    = var.external_secrets_operator_version
  namespace  = "external-secrets"
  create_namespace = true

  values = [
    <<-EOT
    serviceAccount:
      create: true
      name: external-secrets
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
    EOT
  ]
}
