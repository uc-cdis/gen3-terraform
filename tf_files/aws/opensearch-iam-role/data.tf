locals {
  oidc_url = replace(var.oidc_provider_url, "https://", "")
}

data "aws_iam_policy_document" "opensearch_cluster_access" {
  statement {
    actions   = ["es:*"]
    resources = ["${var.opensearch_cluster_arn}/*"]
    effect    = "Allow"
  }
}

data "aws_iam_policy_document" "opensearch_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringLike"
      variable = "${local.oidc_url}:sub"
      values   = ["system:serviceaccount:*:es-proxy"]
    }

    principals {
      identifiers = ["${var.oidc_provider_arn}"]
      type        = "Federated"
    }
  }
}

resource "aws_iam_policy" "opensearch_access_policy" {
  name   = "opensearch-access-policy"
  policy = data.aws_iam_policy_document.opensearch_cluster_access.json
}

resource "aws_iam_role" "opensearch_access_role" {
  name                = "opensearch-access-role"
  assume_role_policy  = data.aws_iam_policy_document.opensearch_assume_role.json
  managed_policy_arns = [aws_iam_policy.opensearch_access_policy.arn]
}
