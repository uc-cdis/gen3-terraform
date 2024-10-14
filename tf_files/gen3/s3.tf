module "manifest-s3-bucket" {
  source = "../aws/modules/generic-bucket"
  bucket_name = "manifestservice-${var.vpc_name}-${var.namespace}"
}

module "grafana-s3-bucket" {
  count = var.namespace == "default" && var.deploy_grafana  ? 1 : 0
  source = "../aws/modules/generic-bucket"
  bucket_name = "${var.vpc_name}-observability-bucket"
}