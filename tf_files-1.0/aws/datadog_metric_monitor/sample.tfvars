#The Datadog API key, used to interface with Datadog
api_key = ""

#The Datadog app key, used to interface with Datadog
app_key = ""

#The URL for the Datadog API. This can be changed if, for example, you are operating in Datadog EU
api_url = "https://api.ddog-gov.com/"

#The name of the commons, for use in messages and test names
commons_name = ""

#Second channel to send notifications to. By default, this module sends notifications to a platform engineering 
#channel, and can also be set to send one to a project-specific alerts channel
project_slack_channel = ""

#The name to give to the synthetic test
monitor_name = "Metric monitor"

#The message to attach to the synthetic test
message = "An API test message"

#A list of strings representing tags, to make it easier to look up this monitor
tags = []

warning_threshold = 2
critical_threshold = 4