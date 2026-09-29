data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Filter out local zones, they can't host these subnets
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

# The VPN instances need CloudWatch Logs, and read/write on the bucket holding
# the PKI so a replacement instance can recover the certs instead of generating new ones
data "aws_iam_policy_document" "vpn_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:GetLogEvents",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy",
    ]
    resources = ["*"]
  }

  # Listing is harmless on either bucket
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = local.pki_bucket_arns
  }

  # Read and write, but only on this stack's own bucket, and only when it has one.
  # A stack adopting another VPN's PKI gets the read only statement below instead.
  dynamic "statement" {
    for_each = local.create_pki_bucket ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
      ]
      resources = ["${aws_s3_bucket.vpn_certs_and_files[0].arn}/*"]
    }
  }

  # Lets the instance turn off its own source/dest check at boot, which AWS requires
  # before it will forward packets for VPN clients. Scoped to instances in this account
  # and region; there is no per-instance ARN condition available for self-modification,
  # so this is as tight as it gets.
  statement {
    effect    = "Allow"
    actions   = ["ec2:ModifyInstanceAttribute"]
    resources = ["arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*"]
  }

  # An adopted bucket belongs to another, usually live, VPN. Read only, so this stack
  # cannot overwrite that VPN's CA, user database or ipp.txt even if something in the
  # container tried to. The PKI_READ_ONLY guard in the entrypoint is the first line of
  # defence; this is the one that actually holds.
  dynamic "statement" {
    for_each = local.override_pki_bucket != "" ? [1] : []
    content {
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::${local.override_pki_bucket}/*"]
    }
  }

  # Read only, just the CA certificate. The instance needs the trust anchor to verify
  # client certs; it has no business issuing them, so IssueCertificate is deliberately
  # not granted to a public facing box.
  dynamic "statement" {
    for_each = var.client_ca_mode == "acmpca" ? [1] : []
    content {
      effect    = "Allow"
      actions   = ["acm-pca:GetCertificateAuthorityCertificate"]
      resources = [var.acm_pca_ca_arn]
    }
  }
}

data "aws_ami" "vpn_ami" {
  most_recent = true
  owners      = [var.ami_account_id]

  filter {
    name   = "name"
    values = [var.image_name_search_criteria]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
