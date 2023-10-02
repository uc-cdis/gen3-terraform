#The Datadog API key, used to interface with Datadog
variable api_key {
  default = ""
}

#The Datadog app key, used to interface with Datadog
variable app_key {
  default = ""
}

#The URL for the Datadog API. This can be changed if, for example, you are operating in Datadog EU
variable api_url {
  default = ""
}

#Whether or not to use secrets manager to store the Datadog API and app keys
variable secrets_manager_enabled {
  default = false
}

#The arn of the secrets manager that contains the Datadog API and app keys
variable datadog_secrets_manager_arn {
  default = ""
}

#The name of the commons, for use in messages and test names
variable commons_name {}

#Second channel to send notifications to. By default, this module sends notifications to a platform engineering 
#channel, and can also be set to send one to a project-specific alerts channel
variable project_slack_channel {}

#The name of the monitor
variable monitor_name {}

#A string representing the query to be run. For more information on how to build a query for a metric monitor, see: 
#https://docs.datadoghq.com/metrics/explorer/
variable query {}

#See https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor#nested-schema-for-monitor_thresholds
variable critical {
  default = ""
}

variable critical_recovery {
  default = ""
}

variable ok {
  default = ""
}

variable unknown {
  default = ""
}

variable warning {
  default = ""
}

variable warning_recovery {
  default = ""
}

#A list of strings representing tags, to make it easier to look up this monitor
variable tags {
  type = list(string)
}
