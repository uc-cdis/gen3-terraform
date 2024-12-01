#The name of the environment
variable environment {}

#The pattern used to filter out logs to forward to datadog. By default, forwards everything
variable filter_pattern {
    default = ""
}

#API key used to authenticate with Datadog
variable datadog_api_key {
    default = ""
}

#Whether or not to use secrets manager to store the Datadog API and app keys
variable secrets_manager_enabled {
  default = false
}

variable datadog_secrets_manager_arn {
  default = ""
}