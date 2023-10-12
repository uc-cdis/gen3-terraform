#The name of the environment
variable environment {}

#The pattern used to filter out logs to forward to datadog. By default, forwards everything
variable filter_pattern {
    default = ""
}

#API key used to authenticate with Datadog
variable datadog_api_key {}