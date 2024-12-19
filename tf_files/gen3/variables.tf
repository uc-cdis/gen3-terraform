variable "ambassador_enabled" {
  description = "Enable ambassador"
  type        = bool
  default     = true
}

variable "arborist_enabled" {
  description = "Enable arborist"
  type        = bool
  default     = true
}

variable "argo_enabled" {
  description = "Enable argo"
  type        = bool
  default     = true
}

variable "audit_enabled" {
  description = "Enable audit"
  type        = bool
  default     = true
}

variable "aurora_username" {
  description = "aurora username"
  default = ""
}

variable "aurora_hostname" {
  description = "aurora hostname"
  default = ""
}

variable "aurora_password" {
  description = "aurora password"
  default = ""
}

variable "aws-es-proxy_enabled" {
  description = "Enable aws-es-proxy"
  type        = bool
  default     = true
}

variable "dbgap_enabled" {
  description = "Enable dbgap sync in the usersync job"
  type        = bool
  default     = false
}

variable "dd_enabled" {
  description = "Enable datadog"
  type        = bool
  default     = false
}

variable "deploy_external_secrets" {
  description = "Deploy external secrets"
  type        = bool
  default     = false
}

variable "deploy_grafana" {
  description = "Deploy grafana"
  type        = bool
  default     = false
  
}

variable "deploy_s3_mountpoint" {
  description = "Deploy s3 mountpoints"
  type        = bool
  default     = false
}

variable "dictionary_url" {
  description = "URL to the data dictionary"
  default     = ""
}

variable "dispatcher_job_number" {
  description = "Number of dispatcher jobs"
  default     = 10
}

variable "dicom-server_enabled" {
  description = "Enable dicom"
  type        = bool
  default     = false
}

variable "dicom-viewer_enabled" {
  description = "Enable dicom server"
  type        = bool
  default     = false
}

variable "es_endpoint" {
  description = "Elasticsearch endpoint"
  default     = ""
}

variable "es_user_key" {
  description = "Elasticsearch user access key"
  default     = ""
}

variable "es_user_secret" {
  description = "Elasticsearch user secret key"
  default     = ""
}

variable "fence_enabled" {
  description = "Enable fence"
  type        = bool
  default     = true
}

variable "gen3ff_enabled" {
  description = "Enable gen3ff"
  type        = bool
  default     = false
}

variable "gen3ff_repo" {
  description = "Gen3ff repo"
  default     = "quay.io/cdis/frontend-framework"
}

variable "gen3ff_tag" {
  description = "Gen3ff tag"
  default     = "main"
}

variable "guppy_enabled" {
  description = "Enable guppy"
  type        = bool
  default     = true
}

variable "hatchery_enabled" {
  description = "Enable hatchery"
  type        = bool
  default     = true
}

variable "hostname" {
  description = "hostname of the commons"
  default = ""
}

variable "indexd_enabled" {
  description = "Enable indexd"
  type        = bool
  default     = true
}

variable "indexd_prefix" {
  description = "Indexd prefix"
  default     = "dg.XXXX/"
}

variable "ingress_enabled" {
  description = "Create ALB ingress"
  type        = bool
  default     = true
}

variable "manifestservice_enabled" {
  description = "Enable manfiestservice"
  type        = bool
  default     = true
}

variable "metadata_enabled" {
  description = "Enable metadata"
  type        = bool
  default     = true
}

variable "netpolicy_enabled" {
  description = "Enable network policy security rules"
  type        = bool
  default     = false
}

variable "peregrine_enabled" {
  description = "Enable perergrine"
  type        = bool
  default     = true
}

variable "pidgin_enabled" {
  description = "Enable pidgin"
  type        = bool
  default     = false
}

variable "portal_enabled" {
  description = "Enable portal"
  type        = bool
  default     = true
}

variable "public_datasets" {
  description = "whether the datasets are public"
  type        = bool
  default     = false
}

variable "requestor_enabled" {
  description = "Enable requestor"
  type        = bool
  default     = false
}

variable "revproxy_arn" {
  description = "ARN for the revproxy cert in ACM"
  default     = ""
}

variable "revproxy_enabled" {
  description = "Enable revproxy"
  type        = bool
  default     = true
}

variable "sheepdog_enabled" {
  description = "Enable sheepdog"
  type        = bool
  default     = true
}

variable "slack_send_dbgap" {
  description = "Enable slack message for usersync job"
  type        = bool
  default     = false
}

variable "slack_webhook" {
  description = "Slack webhook"
  default     = ""  
}

variable "ssjdispatcher_enabled" {
  description = "Enable ssjdispatcher"
  type        = bool
  default     = true
}

variable "sower_enabled" {
  description = "Enable sower"
  type        = bool
  default     = true
}

variable "tier_access_level" {
  description = "Tier access level for guppy"
  default     = "private"
}

variable "tier_access_limit" {
  description = "value for tier access limit"
  default     = "100"
}

variable "usersync_enabled" {
  description = "Enable usersync cronjob"
  type        = bool
  default     = true
}

variable "usersync_schedule" {
  description = "Cronjob schedule for usersync"
  default     = "*/30 * * * *"
}

variable "useryaml_s3_path" {
  description = "S3 path to the user.yaml file"
  default     = "s3://cdis-gen3-users/dev/user.yaml"
}

variable "vpc_name" {
  description = "Name of the VPC"
  default     = ""
}

variable "wts_enabled" {
  description = "Enable wts"
  type        = bool
  default     = true
}

variable "cluster_endpoint" {
 default = ""
}

variable "cluster_ca_cert" {
  default = ""
}

variable "cluster_name" {
  default = ""
}

variable "oidc_provider_arn" {
  default = ""
}

variable "useryaml_path" {
  default = ""
}

variable "gitops_path" {
  default = ""
}

variable "fence_config_path" {
  default = ""
}

variable "google_client_id" {
  default = ""
}

variable "google_client_secret" {
  default = "" 
}

variable "fence_access_key" {
  default = ""
}

variable "fence_secret_key" {
  default = ""
}

variable "upload_bucket" {
  default = ""
}

variable "waf_arn" {
  default = ""
}

variable "namespace" {
  default = "default"
}

variable "deploy_gen3" {
  default = false
}
