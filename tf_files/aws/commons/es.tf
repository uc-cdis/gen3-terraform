module "commons_vpc_es" {
  source                  = "../modules/commons-vpc-es"
  count                   = var.deploy_es ? 1 : 0
  vpc_name                = var.vpc_name
  vpc_id                  = module.cdis_vpc.vpc_id
  instance_type           = var.es_instance_type
  ebs_volume_size_gb      = var.ebs_volume_size_gb
  encryption              = var.encryption
  instance_count          = var.es_instance_count
  organization_name       = var.organization_name
  es_version              = var.es_version
  es_linked_role          = var.es_linked_role
  es_name                 = var.es_name
  role_arn                = var.deploy_es_role ? aws_iam_role.esproxy-role[0].arn : ""
  depends_on              = [module.cdis_vpc.vpc_id, module.cdis_vpc.vpc_peering_id]
}


resource "aws_iam_role" "esproxy-role" {
  count = var.deploy_es_role ? 1 : 0
  name = "${var.vpc_name}-esproxy-sa"
  description = "Role for ES proxy service account for ${var.vpc_name}"
  assume_role_policy = <<EDOC
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Federated": "${module.eks[0].cluster_oidc_provider_arn}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "ForAllValues:StringLike": {
                    "${module.eks[0].oidc_provider_arn}:sub": [
                        "system:serviceaccount:*:esproxy-sa"
                    ],
                    "${module.eks[0].oidc_provider_arn}:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EDOC

  path = "/gen3-service/"
}
