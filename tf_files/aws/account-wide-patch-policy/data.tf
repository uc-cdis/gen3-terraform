data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_ssm_patch_baselines" "baselines" {
  default_baselines = true
}