# Verifies that when admin or user SSH keys are sourced from SSM, the module
# accepts the SSM parameter NAME (a resource identifier) rather than a raw
# string value. Passing the SSM parameter resource's .name attribute creates
# an implicit Terraform dependency on the SSM resource in the calling module.
#
# Providing both the legacy git-path var AND the SSM var for the same key
# set is ambiguous and must be rejected.
#
# RED before the validation blocks are added:
#   "rejects_ambiguous_admin_keys" will FAIL because no validation fires.
# GREEN after the validations are added:
#   Both runs pass.

mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id = "ami-00000000"
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "files/authorized_keys/ops_team"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }
}

run "rejects_ambiguous_admin_keys" {
  command = plan

  variables {
    env_vpc_cidr              = "10.0.0.0/16"
    squid_proxy_subnet        = "10.0.1.0/24"
    env_vpc_name              = "test-vpc"
    env_squid_name            = "squid-auto-test-vpc"
    env_log_group             = "test-vpc"
    env_vpc_id                = "vpc-00000000"
    ssh_key_name              = "test-key"
    squid_availability_zones  = ["us-east-1a"]
    main_public_route         = "rtb-00000000"
    route_53_zone_id          = "Z000000000"

    # Both the legacy git-path var AND the SSM var are set — ambiguous.
    # Expects the var.ssh_admin_keys_ssm_parameter_name validation to fire.
    ssh_admin_keys_file               = "files/authorized_keys/ops_team"
    ssh_admin_keys_ssm_parameter_name = "/squid/test-vpc/admin-keys-file"
  }

  expect_failures = [var.ssh_admin_keys_ssm_parameter_name]
}

run "accepts_ssm_admin_keys" {
  command = plan

  variables {
    env_vpc_cidr              = "10.0.0.0/16"
    squid_proxy_subnet        = "10.0.1.0/24"
    env_vpc_name              = "test-vpc"
    env_squid_name            = "squid-auto-test-vpc"
    env_log_group             = "test-vpc"
    env_vpc_id                = "vpc-00000000"
    ssh_key_name              = "test-key"
    squid_availability_zones  = ["us-east-1a"]
    main_public_route         = "rtb-00000000"
    route_53_zone_id          = "Z000000000"

    # SSM-only: passes the SSM parameter NAME (a resource identifier).
    # Caller would use: ssh_admin_keys_ssm_parameter_name = aws_ssm_parameter.admin_keys.name
    ssh_admin_keys_file               = ""
    ssh_admin_keys_ssm_parameter_name = "/squid/test-vpc/admin-keys-file"
  }
}

run "accepts_legacy_git_admin_keys" {
  command = plan

  variables {
    env_vpc_cidr              = "10.0.0.0/16"
    squid_proxy_subnet        = "10.0.1.0/24"
    env_vpc_name              = "test-vpc"
    env_squid_name            = "squid-auto-test-vpc"
    env_log_group             = "test-vpc"
    env_vpc_id                = "vpc-00000000"
    ssh_key_name              = "test-key"
    squid_availability_zones  = ["us-east-1a"]
    main_public_route         = "rtb-00000000"
    route_53_zone_id          = "Z000000000"

    # Legacy git approach: only the git path var is set.
    ssh_admin_keys_file               = "files/authorized_keys/ops_team"
    ssh_admin_keys_ssm_parameter_name = ""
  }
}
