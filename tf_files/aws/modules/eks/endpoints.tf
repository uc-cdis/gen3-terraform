# EC2 endpoint
resource "aws_vpc_endpoint" "ec2" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = data.aws_vpc.the_vpc.id
  service_name        = data.aws_vpc_endpoint_service.ec2.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [data.aws_security_group.local_traffic.id]
  private_dns_enabled = true
  subnet_ids          = flatten([aws_subnet.eks_private[*].id])

  tags = {
    Name         = "to ec2"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = all
  }
}

# Required for sa-linked IAM roles
resource "aws_vpc_endpoint" "sts" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = data.aws_vpc.the_vpc.id
  service_name        = data.aws_vpc_endpoint_service.sts.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [data.aws_security_group.local_traffic.id]
  private_dns_enabled = true
  subnet_ids          = flatten([aws_subnet.eks_private[*].id])

  tags = {
    Name         = "to sts"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = all
  }
}

# Autoscaling endpoint
resource "aws_vpc_endpoint" "autoscaling" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = data.aws_vpc.the_vpc.id
  service_name        = data.aws_vpc_endpoint_service.autoscaling.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [data.aws_security_group.local_traffic.id]
  private_dns_enabled = true
  subnet_ids          = flatten([aws_subnet.eks_private[*].id])

  tags = {
    Name         = "to autoscaling"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = all
  }
}

# ECR DKR endpoint 
resource "aws_vpc_endpoint" "ecr-dkr" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = data.aws_vpc.the_vpc.id
  service_name        = data.aws_vpc_endpoint_service.ecr_dkr.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [data.aws_security_group.local_traffic.id]
  private_dns_enabled = true
  subnet_ids       = flatten([aws_subnet.eks_private[*].id])

  tags = {
    Name         = "to ecr dkr"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = all
  }
}

# ECR API endpoint 
resource "aws_vpc_endpoint" "ecr-api" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = data.aws_vpc.the_vpc.id
  service_name        = data.aws_vpc_endpoint_service.ecr_api.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [data.aws_security_group.local_traffic.id]
  private_dns_enabled = true
  subnet_ids       = flatten([aws_subnet.eks_private[*].id])

  tags = {
    Name         = "to ecr api"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = all
  }
}

# EBS endpoint
resource "aws_vpc_endpoint" "ebs" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = data.aws_vpc.the_vpc.id
  service_name        = data.aws_vpc_endpoint_service.ebs.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [data.aws_security_group.local_traffic.id]
  private_dns_enabled = true
  subnet_ids       = flatten([aws_subnet.eks_private[*].id])

  tags = {
    Name         = "to ebs"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = all
  }
}


#  S3 endpoint
resource "aws_vpc_endpoint" "k8s-s3" {
  vpc_id          = data.aws_vpc.the_vpc.id
  service_name    = "com.amazonaws.${data.aws_region.current.name}.s3"
  route_table_ids = flatten([data.aws_route_table.public_kube.id, aws_route_table.eks_private[*].id])
  depends_on      = [aws_route_table.eks_private]

  tags = {
    Name         = "to s3"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = all
  }
}

# Cloudwatch logs endpoint
resource "aws_vpc_endpoint" "k8s-logs" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = data.aws_vpc.the_vpc.id
  service_name        = data.aws_vpc_endpoint_service.logs.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [data.aws_security_group.local_traffic.id]
  private_dns_enabled = true
  subnet_ids          = flatten([aws_subnet.eks_private[*].id])

  tags = {
    Name         = "to cloudwatch logs"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = all
  }
}
