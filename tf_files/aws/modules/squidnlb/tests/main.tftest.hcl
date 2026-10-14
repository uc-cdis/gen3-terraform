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

# Required variables that have no defaults in squidnlb
variables {
  env_vpc_id                      = "vpc-12345678"
  env_nlb_name                    = "test-squid-nlb"
  env_vpc_octet1                  = "10"
  env_vpc_octet2                  = "1"
  env_vpc_octet3                  = "0"
  env_public_subnet_routetable_id = "rtb-12345678"
  commons_internal_dns_zone_id    = "ZAAAABBBBCCCC"
}

# TDD: this run FAILS until instance_refresh is added to the ASG (step 3).
run "instance_refresh_rolling_strategy" {
  command = plan

  assert {
    condition     = length(aws_autoscaling_group.squid_nlb.instance_refresh) > 0
    error_message = "instance_refresh block must be configured on the squid NLB ASG"
  }

  assert {
    condition     = aws_autoscaling_group.squid_nlb.instance_refresh[0].strategy == "Rolling"
    error_message = "instance_refresh strategy must be Rolling"
  }

  assert {
    condition     = aws_autoscaling_group.squid_nlb.instance_refresh[0].preferences[0].min_healthy_percentage == 50
    error_message = "instance_refresh must keep at least 50% of instances healthy during rollout"
  }
}

run "launch_template_uses_latest_version" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.squid_nlb.launch_template[0].version == "$Latest"
    error_message = "ASG must reference $Latest so instance_refresh picks up new template versions"
  }
}

run "instance_type_is_t2_medium" {
  command = plan

  assert {
    condition     = module.launch_template.instance_type == "t2.medium"
    error_message = "squidnlb instance type must be t2.medium"
  }
}

# TDD: this run FAILS until iptables-restore is added to the user_data template (step 4).
run "user_data_applies_iptables_on_first_boot" {
  command = plan

  assert {
    condition     = can(regex("iptables-restore", module.launch_template.user_data_decoded))
    error_message = "user_data must call iptables-restore at first boot; squidvm.sh installs the rules but does not apply them"
  }
}

run "user_data_contains_safe_directory_config" {
  command = plan

  assert {
    condition     = can(regex("safe\\.directory", module.launch_template.user_data_decoded))
    error_message = "user_data must configure git safe.directory for the root cron job"
  }
}
