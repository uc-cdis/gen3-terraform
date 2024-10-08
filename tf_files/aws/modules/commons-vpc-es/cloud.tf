locals {
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.the_vpc.id
}

resource "aws_iam_service_linked_role" "es" {
  count            = var.es_linked_role ? 1 : 0
  aws_service_name = "es.amazonaws.com"
}

resource "aws_security_group" "private_es" {
  name        = "private_es"
  description = "security group that allow es port out"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.all_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.all_cidr_blocks
  }

  tags = {
    Environment  = var.vpc_name
    Organization = var.organization_name
  }
}


resource "aws_cloudwatch_log_resource_policy" "es_logs" {
  policy_name     = "es_logs_for_${var.vpc_name}"
  policy_document = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": [
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Resource": "${data.aws_cloudwatch_log_group.logs_group.arn}:*"
    }
  ]
}
CONFIG
}


locals {
  es_policy  = var.role_arn == "" ? local.policy1 : local.policy2
  policy1 = <<POLICY1
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "es:*",
            "Principal": {
              "AWS": [
                "${data.aws_iam_user.es_user.arn}"
              ]
            },
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
POLICY1
  policy2 = <<POLICY2
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "es:*",
            "Principal": {
              "AWS": [
                "${data.aws_iam_user.es_user.arn}",
                "${var.role_arn}"
              ]
            },
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
POLICY2
}

resource "aws_elasticsearch_domain" "gen3_metadata" {
  domain_name           = var.es_name != "" ? var.es_name : "${var.vpc_name}-gen3-metadata"
  elasticsearch_version = var.es_version
  access_policies       = local.es_policy

  encrypt_at_rest {
    # For small instance type like t2.medium, encryption is not available
    enabled = var.encryption
  }

  node_to_node_encryption {
    enabled = var.encryption
  }

  vpc_options {
    security_group_ids = [aws_security_group.private_es.id]
    subnet_ids         = data.aws_subnets.private.ids
  }

  cluster_config {
    instance_type  = var.instance_type
    instance_count = var.instance_count
  }

  ebs_options {
    ebs_enabled = "true"
    volume_size = var.ebs_volume_size_gb
  }

  log_publishing_options {
    log_type                 = "ES_APPLICATION_LOGS"
    cloudwatch_log_group_arn = "${data.aws_cloudwatch_log_group.logs_group.arn}:*"
    enabled                  = "true"
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
  }

  snapshot_options {
    automated_snapshot_start_hour = 23
  }

  lifecycle {
    ignore_changes = [elasticsearch_version]
  }

  tags = {
    Name         = "gen3_metadata"
    Environment  = var.vpc_name
    Organization = var.organization_name

  }

  depends_on = [aws_cloudwatch_log_resource_policy.es_logs, aws_iam_service_linked_role.es]
}
