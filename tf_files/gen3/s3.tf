module "manifest-s3-bucket" {
  source = "../aws/modules/generic-bucket"
  bucket_name = "manifestservice-${var.vpc_name}-${var.namespace}"
}
