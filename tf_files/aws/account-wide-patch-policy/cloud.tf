terraform {
  backend "s3" {
    encrypt = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

locals {
  selected_patch_baselines = jsonencode({
    for baseline in data.aws_ssm_patch_baselines.baselines.baseline_identities : baseline.operating_system => {
      "value" : baseline.baseline_id
      "label" : baseline.baseline_name
      "description" : baseline.baseline_description
      "disabled" : !baseline.default_baseline
    }
  })
}

# =========
# IAM roles
# =========

# Administration role
resource "aws_iam_role" "administration_role" {
  name = "AWS-QuickSetup-PatchPolicy-LocalAdministrationRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudformation.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          StringLike = {
            "aws:SourceArn" = "arn:aws:cloudformation:*:${data.aws_caller_identity.current.account_id}:stackset/AWS-QuickSetup-*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "administration_policy" {
  name = "AWS-QuickSetup-PatchPolicy-LocalAdministrationAssumeRolePolicy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole"
        ]
        Resource = aws_iam_role.execution_role.arn
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "administration_attachment" {
  role = aws_iam_role.administration_role.name
  policy_arn = aws_iam_policy.administration_policy.arn
}


# Execution role
resource "aws_iam_role" "execution_role" {
  name = "AWS-QuickSetup-PatchPolicy-LocalExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.administration_role.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "execution_attachment" {
  role = aws_iam_role.execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSQuickSetupPatchPolicyDeploymentRolePolicy"
}

# ================
# The patch policy
# ================

resource "aws_ssmquicksetup_configuration_manager" "patch_policy_setup" {
  name = "primary-patch-policy"

  depends_on = [aws_iam_role.execution_role, aws_iam_role.administration_role]

  configuration_definition {
    local_deployment_administration_role_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/AWS-QuickSetup-PatchPolicy-LocalAdministrationRole"
    local_deployment_execution_role_name     = "AWS-QuickSetup-PatchPolicy-LocalExecutionRole"
    type                                     = "AWSQuickSetupType-PatchPolicy"

    parameters = {
      "ConfigurationOptionsPatchOperation" : "Scan",
      "ConfigurationOptionsScanValue" : "cron(0 1 * * ? *)",
      "ConfigurationOptionsScanNextInterval" : "false",
      "PatchBaselineRegion" : data.aws_region.current.region,
      "PatchBaselineUseDefault" : "default",
      "PatchPolicyName" : "example",
      "SelectedPatchBaselines" : local.selected_patch_baselines,
      "OutputLogEnableS3" : "false",
      "RateControlConcurrency" : "10%",
      "RateControlErrorThreshold" : "2%",
      "IsPolicyAttachAllowed" : "false",
      "TargetAccounts" : data.aws_caller_identity.current.account_id,
      "TargetRegions" : "us-east-1,us-east-2,us-west-1,us-west-2,sa-east-1,eu-central-1,eu-west-1,eu-west-2,eu-west-3,eu-north-1,ca-central-1,ap-south-1,ap-northeast-1,ap-northeast-2,ap-southeast-1,ap-southeast-2",
      "TargetType" : "*"
    }
  }
}