# Everything a standalone CSOC needs beyond the VPC and EKS cluster, so the
# gen3-admin bootstrap wizard can install CSOC onto the cluster straight after
# apply:
#
#   - IRSA roles for the AWS Load Balancer Controller (the CSOC and Keycloak
#     ingresses are ALBs), the EBS CSI driver (Keycloak's Postgres and the CSOC
#     API need volumes), External Secrets Operator (it copies the CSOC's
#     secrets out of Secrets Manager), and the CSOC API itself (it keeps its
#     environment registry in the Terraform state bucket, and opens GitOps PRs
#     with the GitHub App key in Secrets Manager).
#   - The EBS CSI driver add-on. EKS no longer provisions EBS volumes without
#     it, so PVCs on a fresh cluster stay Pending.
#   - Optionally an ACM certificate for the CSOC and Keycloak hostnames,
#     validated through Route53.

data "aws_partition" "current" {}

locals {
  # Despite its name, the eks module's oidc_provider_arn output is the issuer
  # host (oidc.eks.<region>.amazonaws.com/id/<id>), which is also the prefix
  # IRSA trust conditions are written against.
  oidc_issuer_host  = module.eks.oidc_provider_arn
  oidc_provider_arn = "arn:${data.aws_partition.current.partition}:iam::${local.account_number}:oidc-provider/${local.oidc_issuer_host}"

  csoc_hostname = var.csoc_hostname != "" ? var.csoc_hostname : var.hostname
  cert_names    = compact([local.csoc_hostname, var.keycloak_hostname])

  create_certificate = var.create_certificate && var.certificate_arn == "" && var.hosted_zone_id != "" && local.csoc_hostname != ""
  certificate_arn    = local.create_certificate ? aws_acm_certificate_validation.csoc[0].certificate_arn : var.certificate_arn

  irsa = {
    lb-controller    = { namespace = "kube-system", service_account = "aws-load-balancer-controller" }
    ebs-csi          = { namespace = "kube-system", service_account = "ebs-csi-controller-sa" }
    external-secrets = { namespace = "external-secrets", service_account = "external-secrets" }
    csoc-api         = { namespace = var.csoc_namespace, service_account = var.csoc_service_account }
    # Points each commons' hostname at its load balancer, in the zone below.
    external-dns = { namespace = "external-dns", service_account = "external-dns" }
  }

  # The CSOC's secrets: the GitHub App key, Keycloak's admin login and client
  # secret, and the portal's NextAuth secrets. The wizard and install-csoc
  # create them under this prefix; nothing else here can read them. Secrets
  # Manager appends a random suffix to every secret's ARN, hence the "*".
  csoc_secret_prefix = "gen3-csoc/${var.vpc_name}/"
  csoc_secrets_arn   = "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${local.account_number}:secret:${local.csoc_secret_prefix}*"
}

data "aws_iam_policy_document" "irsa_trust" {
  for_each = local.irsa

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each           = local.irsa
  name               = "${var.vpc_name}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust[each.key].json
  depends_on         = [module.eks]
}

# Upstream policy for the controller version the wizard installs; refresh it
# from kubernetes-sigs/aws-load-balancer-controller docs/install/iam_policy.json
# when that version moves.
resource "aws_iam_policy" "lb_controller" {
  name   = "${var.vpc_name}-lb-controller"
  policy = file("${path.module}/lb_controller_iam_policy.json")
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.irsa["lb-controller"].name
  policy_arn = aws_iam_policy.lb_controller.arn
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.irsa["ebs-csi"].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# The CSOC API reads and writes its environment registry and Terraform state
# (including S3 lock objects, hence DeleteObject) in the state bucket.
data "aws_iam_policy_document" "csoc_api_state" {
  count = var.state_bucket != "" ? 1 : 0

  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning", "s3:GetBucketLocation"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket}"]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket}/*"]
  }
}

resource "aws_iam_role_policy" "csoc_api_state" {
  count  = var.state_bucket != "" ? 1 : 0
  name   = "state-bucket"
  role   = aws_iam_role.irsa["csoc-api"].id
  policy = data.aws_iam_policy_document.csoc_api_state[0].json
}

# External Secrets reads the CSOC's secrets, and only those.
data "aws_iam_policy_document" "external_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [local.csoc_secrets_arn]
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  name   = "csoc-secrets"
  role   = aws_iam_role.irsa["external-secrets"].id
  policy = data.aws_iam_policy_document.external_secrets.json
}

# The CSOC API reads the GitHub App key to open GitOps PRs, and replaces it
# when the repo is reconnected. It cannot read the CSOC's other secrets.
data "aws_iam_policy_document" "csoc_api_github_app" {
  statement {
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "secretsmanager:PutSecretValue"]
    resources = [
      "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${local.account_number}:secret:${local.csoc_secret_prefix}github-app-*",
    ]
  }
}

resource "aws_iam_role_policy" "csoc_api_github_app" {
  name   = "gitops-github-app"
  role   = aws_iam_role.irsa["csoc-api"].id
  policy = data.aws_iam_policy_document.csoc_api_github_app.json
}

# The CSOC requests a certificate for each Gen3 commons it deploys, and writes
# its DNS validation record. Records only in the CSOC's own zone, where the
# commons' hostnames go.
data "aws_iam_policy_document" "csoc_api_certs" {
  count = var.hosted_zone_id != "" ? 1 : 0

  statement {
    actions   = ["acm:RequestCertificate", "acm:DescribeCertificate", "acm:ListCertificates", "acm:AddTagsToCertificate"]
    resources = ["*"]
  }
  statement {
    actions   = ["route53:ListHostedZonesByName", "route53:GetChange"]
    resources = ["*"]
  }
  statement {
    actions   = ["route53:GetHostedZone", "route53:ListResourceRecordSets", "route53:ChangeResourceRecordSets"]
    resources = ["arn:${data.aws_partition.current.partition}:route53:::hostedzone/${var.hosted_zone_id}"]
  }
}

resource "aws_iam_role_policy" "csoc_api_certs" {
  count  = var.hosted_zone_id != "" ? 1 : 0
  name   = "commons-certificates"
  role   = aws_iam_role.irsa["csoc-api"].id
  policy = data.aws_iam_policy_document.csoc_api_certs[0].json
}

# Extra permissions for CSOC to provision commons on its own. Empty by
# default: the bootstrap only needs the registry.
resource "aws_iam_role_policy_attachment" "csoc_api_extra" {
  for_each   = toset(var.csoc_api_policy_arns)
  role       = aws_iam_role.irsa["csoc-api"].name
  policy_arn = each.value
}

# The add-on is created only once its controller runs. On EC2 that waited for
# Karpenter's first node, the apply's last minutes; on Fargate it starts with
# the cluster. Only the controller: the per-node DaemonSet runs on EC2 nodes
# as Karpenter starts them.
resource "aws_iam_role" "fargate_system" {
  name = "${var.vpc_name}-fargate-system"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks-fargate-pods.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_system" {
  role       = aws_iam_role.fargate_system.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

resource "aws_eks_fargate_profile" "ebs_csi" {
  cluster_name           = module.eks.cluster_name
  fargate_profile_name   = "ebs-csi-controller"
  pod_execution_role_arn = aws_iam_role.fargate_system.arn
  subnet_ids             = module.eks.private_subnet_ids
  selector {
    namespace = "kube-system"
    labels    = { app = "ebs-csi-controller" }
  }
  # EKS creates one Fargate profile at a time per cluster; the provider
  # retries while Karpenter's is being created. Not depending on the whole
  # module is the point: that would wait for Karpenter again.
  depends_on = [aws_iam_role_policy_attachment.fargate_system]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.irsa["ebs-csi"].arn
  depends_on               = [aws_iam_role_policy_attachment.ebs_csi, aws_eks_fargate_profile.ebs_csi]
}

# Extra principals (an SSO admin role, say) that should be able to kubectl
# into the cluster. Whoever runs this Terraform is already an admin.
resource "aws_eks_access_entry" "admins" {
  for_each      = toset(var.cluster_admin_arns)
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
}

resource "aws_eks_access_policy_association" "admins" {
  for_each      = toset(var.cluster_admin_arns)
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
  depends_on = [aws_eks_access_entry.admins]
}

resource "aws_acm_certificate" "csoc" {
  count                     = local.create_certificate ? 1 : 0
  domain_name               = local.cert_names[0]
  subject_alternative_names = slice(local.cert_names, 1, length(local.cert_names))
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "csoc_cert_validation" {
  for_each = local.create_certificate ? {
    for o in aws_acm_certificate.csoc[0].domain_validation_options : o.domain_name => o
  } : {}

  zone_id         = var.hosted_zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "csoc" {
  count                   = local.create_certificate ? 1 : 0
  certificate_arn         = aws_acm_certificate.csoc[0].arn
  validation_record_fqdns = [for r in aws_route53_record.csoc_cert_validation : r.fqdn]
}

# external-dns writes the DNS records for the commons the CSOC deploys:
# only in the CSOC's zone, and only records it owns (TXT ownership).
data "aws_iam_policy_document" "external_dns" {
  count = var.hosted_zone_id != "" ? 1 : 0
  statement {
    actions   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets", "route53:ListTagsForResource"]
    resources = ["arn:${data.aws_partition.current.partition}:route53:::hostedzone/${var.hosted_zone_id}"]
  }
  statement {
    actions   = ["route53:ListHostedZones", "route53:ListHostedZonesByName"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "external_dns" {
  count  = var.hosted_zone_id != "" ? 1 : 0
  name   = "commons-dns"
  role   = aws_iam_role.irsa["external-dns"].id
  policy = data.aws_iam_policy_document.external_dns[0].json
}
