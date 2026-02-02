resource "aws_cloudwatch_metric_alarm" "es_alarm" {
  alarm_name                =  "${var.vpc_name}-es-cluster-red"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "ClusterStatus.red"
  namespace                 = "AWS/EC2"
  period                    = 60
  statistic                 = "Maximum"
  threshold                 = 1
  alarm_description         = "This metric monitors elasticsearch cluster health."
  insufficient_data_actions = []
  actions_enabled = true
  alarm_actions = [aws_lambda_function.es_lambda.arn]
  dimensions = {
    DomainName = var.es_name
  }
}

resource "aws_lambda_function" "es_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  # filename         = "lambda_function_payload.zip"
  function_name    = "es-cluster-red-slack-alert"
  role             = aws_iam_role.lambda_es_cluster_red_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.14"
  # source_code_hash = filebase64sha256("lambda_function_payload.zip")
  timeout          = 60
  environment {
    variables = {
      SLACK_WEBHOOK_SECRET_NAME = data.aws_secretsmanager_secret.slack_webhook.name
      VPC_NAME = var.vpc_name
    }
  }
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowCloudWatchAlarmInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.es_lambda.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"
  source_arn    = aws_cloudwatch_metric_alarm.es_alarm.arn
}

resource "aws_iam_role" "lambda_es_cluster_red_role" {
  name  = "${var.vpc_name}-lambda-es-cluster-red-role"

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

resource "aws_iam_role_policy" "lambda_es_cluster_red_policy" {
  name  = "${var.vpc_name}-lambda-es-cluster-red-policy"
  role  = aws_iam_role.lambda_es_cluster_red_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = ["rds:secretsmanager:GetSecretValue"],
        Resource = data.aws_secretsmanager_secret.slack_webhook.arn
      }
    ]
  })
}
