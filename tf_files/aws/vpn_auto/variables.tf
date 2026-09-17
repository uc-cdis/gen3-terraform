variable "env_vpn_name" {}

variable "env_cloud_name" {}

variable "env_vpc_id" {}

variable "vpn_server_subnet" {}

variable "csoc_vpn_subnet" {}

variable "csoc_vm_subnet" {}

variable "env_pub_subnet_routetable_id" {}

variable "csoc_planx_dns_zone_id" {}

variable "enable_deletion_protection" {
  type    = bool
  default = true
}

variable "manage_dns_record" {
  type    = bool
  default = true
}

variable "dns_record_name" {
  default = ""
}

variable "dns_record_ttl" {
  default = 300
}

variable "ssh_key_name" {}

variable "cwl_group_name" {}

variable "pushed_routes" {
  type    = list(string)
  default = ["10.128.0.0/12", "172.16.0.0/12"]
}

variable "dnsmasq_overrides" {
  type    = map(string)
  default = {}
}

variable "vpn_instance_type" {
  default = "c6i.large"
}

variable "vpn_instance_drive_size" {
  default = 30
}

variable "vpn_availability_zones" {
  type    = list(string)
  default = []
}

variable "ami_account_id" {
  default = "137112412989"
}

variable "image_name_search_criteria" {
  default = "al2023-ami-2023*-x86_64"
}

variable "ssm_parameter_name" {
  default = ""
}

variable "client_ca_mode" {
  default = "easyrsa"
}

variable "acm_pca_ca_arn" {
  default = ""
}

variable "s3_prefix_override" {
  default = ""
}

variable "vpn_image_tag" {
  default = "master"
}

variable "organization_name" {
  default = "Basic Services"
}

variable "cluster_desired_capacity" {
  default = 1
}

variable "cluster_min_size" {
  default = 1
}

variable "cluster_max_size" {
  default = 2
}
