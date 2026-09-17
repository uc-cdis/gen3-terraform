terraform {
  backend "s3" {
    encrypt = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "vpn_auto" {
  source                       = "../modules/vpn_auto"
  env_vpn_name                 = var.env_vpn_name
  env_cloud_name               = var.env_cloud_name
  env_vpc_id                   = var.env_vpc_id
  vpn_server_subnet            = var.vpn_server_subnet
  csoc_vpn_subnet              = var.csoc_vpn_subnet
  csoc_vm_subnet               = var.csoc_vm_subnet
  env_pub_subnet_routetable_id = var.env_pub_subnet_routetable_id
  csoc_planx_dns_zone_id       = var.csoc_planx_dns_zone_id
  enable_deletion_protection   = var.enable_deletion_protection
  manage_dns_record            = var.manage_dns_record
  dns_record_name              = var.dns_record_name
  dns_record_ttl               = var.dns_record_ttl
  ssh_key_name                 = var.ssh_key_name
  cwl_group_name               = var.cwl_group_name
  pushed_routes                = var.pushed_routes
  dnsmasq_overrides            = var.dnsmasq_overrides
  vpn_instance_type            = var.vpn_instance_type
  vpn_instance_drive_size      = var.vpn_instance_drive_size
  vpn_availability_zones       = var.vpn_availability_zones
  ami_account_id               = var.ami_account_id
  image_name_search_criteria   = var.image_name_search_criteria
  ssm_parameter_name           = var.ssm_parameter_name
  client_ca_mode               = var.client_ca_mode
  acm_pca_ca_arn               = var.acm_pca_ca_arn
  s3_prefix_override           = var.s3_prefix_override
  vpn_image_tag                = var.vpn_image_tag
  organization_name            = var.organization_name
  cluster_desired_capacity     = var.cluster_desired_capacity
  cluster_min_size             = var.cluster_min_size
  cluster_max_size             = var.cluster_max_size
}
