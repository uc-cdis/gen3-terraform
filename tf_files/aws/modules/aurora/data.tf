###############
# Collect data
###############

data "aws_caller_identity" "current" {}

# collect vpc_security_group_ids  from vpc_id and security group name
data "aws_vpcs" "vpcs" {
  tags = {
    Name = var.vpc_name
  }
}

data "aws_security_group" "private" {
  vpc_id = data.aws_vpc.the_vpc.id
  name   = "local"
}

data "aws_vpc" "the_vpc" {
  id = data.aws_vpcs.vpcs.ids[0]
}

# let terraform compress our code and serve to lambda
data "archive_file" "lambda_function" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "lambda_function_payload.zip"
}