resource "aws_iam_role" "opensearch_iam_role" {
  name               = "${var.environment}-elasticsearch-access-role"
  assume_role_policy = data.aws_iam_policy_document.opensearch_assume_role.json
}

resource "aws_iam_policy" "opensearch_iam_role_policy" {
  name   = "opensearch_access_policy"
  policy = data.aws_iam_policy_document.opensearch_cluster_access.json
}

resource "aws_iam_role_policy_attachment" "opensearch" {
  role       = aws_iam_role.opensearch_iam_role.name
  policy_arn = aws_iam_policy.opensearch_iam_role_policy.arn
}
