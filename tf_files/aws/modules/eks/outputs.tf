output "kubeconfig" {
  value     = templatefile("${path.module}/kubeconfig.tpl", { vpc_name = var.vpc_name, eks_name = aws_eks_cluster.eks_cluster.id, eks_endpoint = aws_eks_cluster.eks_cluster.endpoint, eks_cert = aws_eks_cluster.eks_cluster.certificate_authority.0.data, })
  sensitive = true
}

output "config_map_aws_auth" {
  value     = local.config-map-aws-auth
  sensitive = true
}

output "cluster_endpoint" {
  value     = aws_eks_cluster.eks_cluster.endpoint
  sensitive = true
}

output "cluster_certificate_authority_data" {
  value     = aws_eks_cluster.eks_cluster.certificate_authority.0.data
  sensitive = true
}

output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "oidc_provider_arn" {
  value = replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")
}

output "cluster_oidc_provider_url" {
  value = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

output "cluster_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.identity_provider[0].arn
}
