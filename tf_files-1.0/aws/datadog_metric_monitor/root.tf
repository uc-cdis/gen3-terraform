terraform {
  required_providers {
    datadog = {
      source = "DataDog/datadog"
    }
  }
}

provider "datadog" {
    api_key = var.api_key
    app_key = var.app_key
    api_url = var.api_url
}


resource "datadog_monitor" "metric_monitor" {
  name               = "${var.monitor_name}"
  type               = "metric alert"
  message            = "Metric monitor ${var.monitor_name} was triggered in ${var.commons_name} @slack-gpe-alarms @${var.project_slack_channel}"

  query = "${var.query}"


  dynamic "monitor_thresholds" {
    for_each = var.threshold_specificatons[*]

    content {
      critical = threshold_specificatons.value.critical
      critical_recovery = threshold_specificatons.value.critical_recovery
      ok = threshold_specificatons.value.ok
      unknown = threshold_specificatons.value.unknown
      warning = threshold_specificatons.value.warning
      warning_recover = threshold_specificatons.value.warning_recover
    }
  }

  include_tags = true

  tags = var.tags
}