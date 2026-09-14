# Verifies that role_arn must be provided explicitly so Terraform can track
# the dependency from the ES domain back to the IAM principal that created it.
#
# Without an explicit role_arn, the module falls back to
# data.aws_iam_user.es_user which looks up by name — breaking the implicit
# dependency between the IAM user resource and the ES domain in the calling
# module. This causes a race condition on the first terraform apply.
#
# RED before the validation is added to var.role_arn:
#   "rejects_empty_role_arn" will FAIL because no validation fires.
# GREEN after the validation is added:
#   Both runs pass.

mock_provider "aws" {
  mock_data "aws_vpcs" {
    defaults = {
      ids = ["vpc-00000000"]
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id                       = "vpc-00000000"
      cidr_block_associations  = []
    }
  }

  mock_data "aws_subnets" {
    defaults = {
      ids = ["subnet-00000000"]
    }
  }

  mock_data "aws_cloudwatch_log_group" {
    defaults = {
      arn  = "arn:aws:logs:us-east-1:123456789012:log-group:test-vpc"
      name = "test-vpc"
    }
  }

  mock_data "aws_iam_user" {
    defaults = {
      arn       = "arn:aws:iam::123456789012:user/test-vpc_es_user"
      user_name = "test-vpc_es_user"
    }
  }
}

run "rejects_empty_role_arn" {
  command = plan

  variables {
    vpc_name = "test-vpc"
    role_arn = ""
  }

  # Expects the var.role_arn validation to fire and reject the empty value.
  # This run FAILS (test is red) until the validation block is added.
  expect_failures = [var.role_arn]
}

run "accepts_explicit_role_arn" {
  command = plan

  variables {
    vpc_name = "test-vpc"
    role_arn = "arn:aws:iam::123456789012:user/test-vpc_es_user"
  }
}
