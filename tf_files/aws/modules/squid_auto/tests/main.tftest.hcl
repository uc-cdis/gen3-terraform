mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}
mock_provider "null" {}

# Required variables that have no defaults in squid_auto
variables {
  env_vpc_cidr              = "10.1.0.0/16"
  squid_proxy_subnet        = "10.1.1.0/24"
  env_vpc_name              = "test-vpc"
  env_squid_name            = "test-squid"
  env_log_group             = "/gen3/test-vpc/squid"
  env_vpc_id                = "vpc-12345678"
  ssh_key_name              = "test-key"
  squid_availability_zones  = ["us-east-1a"]
  main_public_route         = "rtb-12345678"
  route_53_zone_id          = "ZAAAABBBBCCCC"
}

# TDD: this run FAILS until instance_refresh is added to the ASG (step 3).
run "instance_refresh_rolling_strategy" {
  command = plan

  assert {
    condition     = length(aws_autoscaling_group.squid_auto.instance_refresh) > 0
    error_message = "instance_refresh block must be configured on the squid ASG"
  }

  assert {
    condition     = aws_autoscaling_group.squid_auto.instance_refresh[0].strategy == "Rolling"
    error_message = "instance_refresh strategy must be Rolling"
  }

  assert {
    condition     = aws_autoscaling_group.squid_auto.instance_refresh[0].preferences[0].min_healthy_percentage == 50
    error_message = "instance_refresh must keep at least 50% of instances healthy during rollout"
  }
}

run "launch_template_uses_latest_version" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.squid_auto.launch_template[0].version == "$Latest"
    error_message = "ASG must reference $Latest so instance_refresh picks up new template versions"
  }
}

run "user_data_contains_safe_directory_config" {
  command = plan

  assert {
    condition     = can(regex("safe\\.directory", module.launch_template.user_data_decoded))
    error_message = "user_data must configure git safe.directory to allow root cron git pulls"
  }
}
