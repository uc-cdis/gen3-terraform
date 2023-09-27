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

  monitor_thresholds {
    warning  = var.warning_threshold
    critical = var.critical_threshold
  }

  include_tags = true

  tags = var.tags
}