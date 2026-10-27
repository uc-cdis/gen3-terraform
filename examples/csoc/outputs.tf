# Read by the gen3-admin bootstrap wizard after apply to install CSOC onto the
# cluster. None of these are secrets; the wizard stores them in its registry.

output "cluster_name" {
  value = module.eks.cluster_name
}

output "aws_region" {
  value = var.aws_region
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "oidc_provider_arn" {
  value = local.oidc_provider_arn
}

output "lb_controller_role_arn" {
  value = aws_iam_role.irsa["lb-controller"].arn
}

output "external_secrets_role_arn" {
  value = aws_iam_role.irsa["external-secrets"].arn
}

output "csoc_secret_prefix" {
  value = local.csoc_secret_prefix
}

output "csoc_api_role_arn" {
  value = aws_iam_role.irsa["csoc-api"].arn
}

output "certificate_arn" {
  value = local.certificate_arn
}

output "csoc_hostname" {
  value = local.csoc_hostname
}

output "keycloak_hostname" {
  value = var.keycloak_hostname
}

output "hosted_zone_id" {
  value = var.hosted_zone_id
}

output "external_dns_role_arn" {
  value = aws_iam_role.irsa["external-dns"].arn
}
