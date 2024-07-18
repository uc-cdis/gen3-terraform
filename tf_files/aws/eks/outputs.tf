output "kubeconfig" {
  value = module.eks[0].kubeconfig
}

output "config_map_aws_auth" {
  value = module.eks[0].config_map_aws_auth
}

output "cluster_oidc_provider_url" {
  value = module.eks[0].cluster_oidc_provider_url
}

output "cluster_oidc_provider_arn" {
  value = module.eks[0].cluster_oidc_provider_arn
}
