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

resource "aws_ssmquicksetup_configuration_manager" "patch_policy_setup" {
  name = "primary-patch-policy"

  configuration_definition {
    local_deployment_administration_role_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/csoc_adminvm"
    local_deployment_execution_role_name     = "csoc_adminvm"
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