output "kubeconfig" {
  value = module.eks[0].kubeconfig
}



output "cluster_oidc_provider_url" {
  value = module.eks[0].cluster_oidc_provider_url
}

