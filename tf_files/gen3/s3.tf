module "manifest-s3-bucket" {
  source = "../aws/modeules/generic-bucket"
  bucket_name = "manifestservice-${var.vpc_name}-${var.namespace}"
}
