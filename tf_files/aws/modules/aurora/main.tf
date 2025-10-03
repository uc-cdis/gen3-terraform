#########################
# Create Master password
#########################

resource "random_password" "password" {
  length  = var.password_length
  special = false
}

#############
# RDS Aurora
#############

# Aurora Cluster

resource "aws_rds_cluster" "postgresql" {
  cluster_identifier              = "${var.vpc_name}-${var.cluster_identifier}"
  engine                          = var.cluster_engine
  engine_version	                = var.cluster_engine_version
  db_subnet_group_name	          = "${var.vpc_name}_private_group"
  vpc_security_group_ids          = [data.aws_security_group.private.id]
  master_username                 = var.master_username
  master_password	                = random_password.password.result
  storage_encrypted	              = var.storage_encrypted
  apply_immediately               = var.apply_immediate
  engine_mode        	            = var.engine_mode
  skip_final_snapshot	            = var.skip_final_snapshot
  final_snapshot_identifier       = "${var.vpc_name}-${var.final_snapshot_identifier}"
  backup_retention_period         = var.backup_retention_period
  preferred_backup_window         = var.preferred_backup_window
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_cdis_pg.name
  kms_key_id                      = var.db_kms_key_id 

  serverlessv2_scaling_configuration {
    max_capacity = var.serverlessv2_scaling_max_capacity
    min_capacity = var.serverlessv2_scaling_min_capacity
  }

  lifecycle {
    ignore_changes  = [kms_key_id, engine_version]
  }
}

# Aurora Cluster Instance

resource "aws_rds_cluster_instance" "postgresql" {
  db_subnet_group_name = aws_rds_cluster.postgresql.db_subnet_group_name
  identifier         	 = "${var.vpc_name}-${var.cluster_instance_identifier}"
  cluster_identifier 	 = aws_rds_cluster.postgresql.id
  instance_class	     = var.cluster_instance_class
  engine             	 = aws_rds_cluster.postgresql.engine
  engine_version     	 = aws_rds_cluster.postgresql.engine_version

  lifecycle {
    ignore_changes = [engine_version]
  }
}


#############################
# Aurora Creds to Local File
#############################

# Local variable to hold aurora creds
locals {
  aurora-creds-template     = <<AURORACREDS
{
    "aurora": {
        "db_host": "${aws_rds_cluster.postgresql.endpoint}",
        "db_username": "${aws_rds_cluster.postgresql.master_username}",
        "db_password": "${aws_rds_cluster.postgresql.master_password}",
    }
}
AURORACREDS
}

# generating aurora-creds.json
resource "local_sensitive_file" "aurora_creds" {
  count    = var.secrets_manager_enabled ? 0 : 1
  content  = local.aurora-creds-template
  filename = "${path.cwd}/${var.vpc_name}_output/aurora-creds.json"
}

module "secrets_manager" {
  count       = var.secrets_manager_enabled ? 1 : 0
  source      = "../secrets_manager"
  vpc_name    = var.vpc_name
  secret	    = templatefile("${path.module}/secrets_manager.tftpl", {
    hostname = aws_rds_cluster.postgresql.endpoint
    database = "postgres"
    username = aws_rds_cluster.postgresql.master_username
    password = aws_rds_cluster.postgresql.master_password
  })
  secret_name = "aurora-master-password"
}

# See https://www.postgresql.org/docs/9.6/static/runtime-config-logging.html
# and https://www.postgresql.org/docs/9.6/static/runtime-config-query.html#RUNTIME-CONFIG-QUERY-ENABLE
# for detail parameter descriptions
locals {
  pg_family_version = replace( var.cluster_engine_version ,"/\\.[0-9]/", "" )
}

resource "aws_rds_cluster_parameter_group" "aurora_cdis_pg" {
  name   = "${var.vpc_name}-aurora-cdis-pg"
  family = "aurora-postgresql${local.pg_family_version}"

  # make index searches cheaper per row
  parameter {
    name  = "cpu_index_tuple_cost"
    value = "0.000005"
  }

  # raise cost of search per row to be closer to read cost
  # suggested for SSD backed disks
  parameter {
    name  = "cpu_tuple_cost"
    value = "0.7"
  }

  # Log the duration of each SQL statement
  parameter {
    name  = "log_duration"
    value = "1"
  }

  # Log statements above this duration
  # 0 = everything
  parameter {
    name  = "log_min_duration_statement"
    value = "0"
  }

  # lower cost of random reads from disk because we use SSDs
  parameter {
    name  = "random_page_cost"
    value = "0.7"
  }

  # Set the scram password encryption so that connecting with FIPs enabled works
  parameter {
    name  = "password_encryption"
    value = "scram-sha-256"
  }

  lifecycle {
    ignore_changes  = all
  }
}

resource "aws_iam_role" "lambda_rds_check_role" {
  count = var.deploy_rds_check_lambda ? 1 : 0
  name  = "lambda-rds-check-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_rds_check_policy" {
  count = var.deploy_rds_check_lambda ? 1 : 0
  name  = "lambda-rds-check-policy"
  role  = aws_iam_role.lambda_rds_check_role[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = ["rds:DescribePendingMaintenanceActions"],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = ["cloudwatch:PutMetricData"],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "rds_upgrade_checker" {
  count            = var.deploy_rds_check_lambda ? 1 : 0
  filename         = "lambda_function_payload.zip" 
  function_name    = "rds-upgrade-checker"
  role             = aws_iam_role.lambda_rds_check_role[0].arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  timeout          = 60
  memory_size      = 128
}

resource "aws_cloudwatch_event_rule" "rds_upgrade_schedule" {
  count              = var.deploy_rds_check_lambda ? 1 : 0
  name                = "rds-upgrade-schedule"
  schedule_expression = "rate(12 hours)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  count     = var.deploy_rds_check_lambda ? 1 : 0
  rule      = aws_cloudwatch_event_rule.rds_upgrade_schedule[0].name
  target_id = "lambda"
  arn       = aws_lambda_function.rds_upgrade_checker[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count         = var.deploy_rds_check_lambda ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_upgrade_checker[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_upgrade_schedule[0].arn
}
