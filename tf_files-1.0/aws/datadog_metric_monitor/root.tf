terraform {
  required_providers {
    datadog = {
      source = "DataDog/datadog"
    }
  }
}

locals {
  api_key = var.secrets_manager_enabled ? jsondecode(data.aws_secretsmanager_secret_version.secrets.secret_string)["api-key"] : var.api_key
  app_key = var.secrets_manager_enabled ? jsondecode(data.aws_secretsmanager_secret_version.secrets.secret_string)["application-key"] : var.app_key
  api_url = var.secrets_manager_enabled ? jsondecode(data.aws_secretsmanager_secret_version.secrets.secret_string)["url"] : var.api_url
}

provider "datadog" {
    api_key = local.api_key
    app_key = local.app_key
    api_url = local.api_url
}


resource "datadog_monitor" "metric_monitor" {
  name               = "${var.monitor_name}"
  type               = "metric alert"
  message            = "Metric monitor ${var.monitor_name} was triggered in ${var.commons_name} @slack-gpe-alarms @${var.project_slack_channel}"

  query = "${var.query}"


  monitor_thresholds {
    critical = var.critical
    critical_recovery = var.critical_recovery
    ok = var.ok
    unknown = var.unknown
    warning = var.warning
    warning_recovery = var.warning_recovery
  }

  include_tags = true

  tags = var.tags
}