variable "env_vpn_name" {
  description = "Name of the VPN deployment, used to name most resources. Should match the FQDN prefix, ie csoc-dev-vpn-2024"
}

variable "env_cloud_name" {
  description = "Hostname/OU given to the VPN server, ie planx-dev-vpn-2024. Used by easy-rsa as the server cert CN"
}

variable "env_vpc_id" {
  description = "The VPC id where the VPN cluster will reside"
}

variable "vpn_server_subnet" {
  description = "CIDR that gets carved into per-AZ /28s for the VPN server subnets, ie 10.128.6.0/25"
}

variable "csoc_vpn_subnet" {
  description = "The OpenVPN client network. Clients get addresses out of this range, ie 192.168.3.0/24"
}

variable "csoc_vm_subnet" {
  description = "Network the VPN clients need to reach. Also the only CIDR allowed to ssh in, ie 10.128.7.0/24"
}

variable "env_pub_subnet_routetable_id" {
  description = "The route table that gives the VPN subnets public access"
}

variable "csoc_planx_dns_zone_id" {
  description = "Route53 zone id used to add the VPN CNAME"
}

variable "manage_dns_record" {
  description = "Whether this module owns the CNAME. Set false if DNS is cut over by hand during a blue/green"
  type        = bool
  default     = true
}

variable "dns_record_name" {
  description = "CNAME to point at this NLB. Defaults to env_vpn_name. Set to the hostname clients already use to cut traffic over to this stack"
  default     = ""
}

variable "dns_record_ttl" {
  description = "TTL on the CNAME. Keep it low around a cutover"
  default     = 300
}

variable "ssh_key_name" {
  description = "Name of the aws_key_pair to attach to the instances"
}

variable "cwl_group_name" {
  description = "CloudWatch Logs group name for the instance logs"
}

variable "pushed_routes" {
  description = "Routes pushed to VPN clients. Defaults match what csoc-prod-vpn-2024 pushes today"
  type        = list(string)
  default     = ["10.128.0.0/12", "172.16.0.0/12"]
}

# Split horizon DNS. While on the VPN these hostnames must resolve to the internal
# load balancer instead of the public one. update-dnsmasq.sh resolves each value and
# writes the resulting A records to /etc/dnsmasq.hosts
variable "dnsmasq_overrides" {
  description = "Map of hostname to the internal load balancer DNS name it should resolve to"
  type        = map(string)
  default     = {}
}

variable "vpn_instance_type" {
  description = "Instance type for the VPN instances"
  default     = "m5.xlarge"
}

variable "vpn_instance_drive_size" {
  description = "Size of the root volume, in GB"
  default     = 30
}

variable "vpn_availability_zones" {
  description = "AZs to deploy the VPN subnets into. Empty means every AZ available in the region"
  type        = list(string)
  default     = []
}

# Amazon owns the AL2023 images
variable "ami_account_id" {
  description = "AWS account id that owns the AMI to search for"
  default     = "137112412989"
}

variable "image_name_search_criteria" {
  description = "Criteria used to find an AMI in the account above"
  default     = "al2023-ami-2023*-x86_64"
}

variable "ssm_parameter_name" {
  description = "If set, this AMI id is used verbatim and the aws_ami lookup is skipped. Useful to pin an image"
  default     = ""
}

variable "vpn_image_tag" {
  description = "Tag of the quay.io/cdis/openvpn image to run"
  default     = "main"
}

variable "organization_name" {
  description = "For tagging purposes"
  default     = "Basic Services"
}

variable "cluster_desired_capacity" {
  description = "Desired number of VPN instances. Certs live in S3 so more than one is possible, but the NLB has no stickiness"
  default     = 1
}

variable "cluster_min_size" {
  default = 1
}

variable "cluster_max_size" {
  description = "Allow one extra so create_before_destroy style replacements have room"
  default     = 2
}
