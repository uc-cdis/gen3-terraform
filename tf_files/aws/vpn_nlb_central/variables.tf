variable "csoc_vpn_subnet"{}

variable "csoc_vm_subnet"{}

variable "vpn_server_subnet"{}

variable "env_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "env_vpn_nlb_name" {
  #default = "csoc-vpn-nlb"
  #Have it same as FQDN
  default = "csoc-prod-vpn"
}

variable "env_cloud_name" {
  default = "planxprod"
}

# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  default = "099720109477"
}

variable "image_name_search_criteria" {
  default = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018*"
}

variable "env_pub_subnet_routetable_id" {
  default = "rtb-1cb66860"
}

variable "csoc_planx_dns_zone_id" {
  default = "ZG153R4AYDHHK"
}

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {
  default = "rarya_id_rsa"
}

## variable for the bootstrap 
variable "bootstrap_path" {
  default = "cloud-automation/flavors/vpn_nlb_central/"
}

variable "bootstrap_script" {
  default = "vpnvm.sh"
}

variable "organization_name" {
  default = "Basic Services"
}

variable "branch" {
  default = "master"
}

variable "cwl_group_name" {
  default     = "csoc-prod-vpn.planx-pla.net_log_group"
}
