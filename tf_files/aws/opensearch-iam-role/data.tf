locals {
  oidc_url = replace(var.oidc_url, "https://", "")
}

data "aws_iam_policy_document" "opensearch_cluster_access" {
  statement {
    actions   = ["es:*"]
    resources = ["${var.opensearch_cluster_arn}"]
    effect    = "Allow"
  }
}

data "aws_iam_policy_document" "opensearch_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringLike"
      variable = "${locals.oidc_url}:sub"
      values   = ["system:serviceaccount:*:es-proxy"]
    }

    principals {
      identifiers = ["${var.oidc_provider_arn}"]
      type        = "Federated"
    }
  }
}
