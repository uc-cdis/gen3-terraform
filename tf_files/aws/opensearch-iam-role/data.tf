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
      test     = "StringEquals"
      variable = var.oidc_url
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}
