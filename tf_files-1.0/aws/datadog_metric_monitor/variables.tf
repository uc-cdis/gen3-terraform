#The Datadog API key, used to interface with Datadog
variable api_key {}

#The Datadog app key, used to interface with Datadog
variable app_key {}

#The URL for the Datadog API. This can be changed if, for example, you are operating in Datadog EU
variable api_url {}

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
variable threshold_specifications {
    type = map
    description = "The specifications for notification thresholds"
}

#A list of strings representing tags, to make it easier to look up this monitor
variable tags {}