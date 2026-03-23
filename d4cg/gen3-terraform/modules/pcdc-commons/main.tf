module "commons" {
  source = "../../../../tf_files/aws/commons"

  vpc_name=var.vpc_name
  vpc_cidr_block=var.vpc_cidr_block
  aws_region=var.aws_region
  hostname=var.hostname
  kube_ssh_key=var.kube_ssh_key
  ami_account_id=var.ami_account_id
  squid_image_search_criteria=var.squid_image_search_criteria
  ha-squid_instance_drive_size=var.ha-squid_instance_drive_size
  deploy_ha_squid=var.deploy_ha_squid
  deploy_sheepdog_db=var.deploy_sheepdog_db
  deploy_fence_db=var.deploy_fence_db
  deploy_indexd_db=var.deploy_indexd_db
  network_expansion=var.network_expansion
  users_policy=var.users_policy
  availability_zones=var.availability_zones
  es_version=var.es_version
  es_linked_role=var.es_linked_role
  cluster_engine_version=var.cluster_engine_version
  deploy_aurora=var.deploy_aurora
  deploy_rds=var.deploy_rds
  use_asg=var.use_asg
  use_karpenter=var.use_karpenter
  deploy_karpenter_in_k8s=var.deploy_karpenter_in_k8s
  send_logs_to_csoc=var.send_logs_to_csoc
  secrets_manager_enabled=var.secrets_manager_enabled
  force_delete_bucket=var.force_delete_bucket
  enable_vpc_endpoints=var.enable_vpc_endpoints
  deploy_es=var.deploy_es
  deploy_es_role=var.deploy_es_role
}

module "amanuensis-data-release-bucket" {
  source   = "../amanuensis-data-release-bucket"
  vpc_name = var.vpc_name
}

module "amanuensis-bot-user" {
  source             = "../bot-user"
  vpc_name           = var.vpc_name
  bot_name           = "amanuensis"
  bucket_name        = module.amanuensis-data-release-bucket.bucket_name
  bucket_access_arns = var.amanuensis-bot_bucket_access_arns
}
