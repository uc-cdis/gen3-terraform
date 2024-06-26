data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_vpcs" "vpcs" {
  tags = {
    Name = var.vpc_name
  }
}

# Assuming that there is only one VPC with the vpc_name
data "aws_vpc" "the_vpc" {
  id = data.aws_vpcs.vpcs.ids[0]
}

locals {
  all_cidr_blocks = [for assoc in data.aws_vpc.the_vpc.cidr_block_associations : assoc.cidr_block]
}

data "aws_iam_user" "es_user" {
  user_name = "${var.vpc_name}_es_user"
}

data "aws_cloudwatch_log_group" "logs_group" {
  name = var.vpc_name
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.the_vpc.id]
  }
  tags = {
    Name = "private_db_alt"
  }
}
