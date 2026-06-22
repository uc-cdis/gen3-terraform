variable "env_vpc_cidr" {
  description = "CIDR of the VPC where this cluster will reside"
}

variable "squid_proxy_subnet" {}

variable "env_vpc_name" {}

variable "env_squid_name" {}

# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  default = "137112412989"
}

variable "image_name_search_criteria" {
  default = "al2023-ami-*"
}

variable "peering_cidr" {
  default = "10.128.0.0/20"
}

variable "secondary_cidr_block" {
  default = ""
}

## variable for the bootstrap 
variable "bootstrap_path" {
  default = "cloud-automation/flavors/squid_auto/"
}

variable "bootstrap_script" {
  default = "squid_running_on_docker.sh"
}

variable "squid_instance_type" {
  description = "instance type that replicas of squid will be deployed into"
  default     = "t3.medium"
}

variable "organization_name" {
  description = "basically for tagging porpuses"
  default     = "Basic Services"
}

variable "env_log_group" {
  description = "log group in which to send logs from the instance"
}

variable "env_vpc_id" {
  description = "the vpc id where the proxy cluster will reside"
}

variable "ssh_key_name" {
  description = "ssh key name that instances in the cluster will use"
}

variable "squid_instance_drive_size" {
  description = "Size of the root volume for the instance"
  default     = 8
}

variable "squid_availability_zones" {
  description = "AZs on wich to associate the routes for the squid proxies"
}

variable "main_public_route" {
  description = "The route table that allows public access"
}

variable "route_53_zone_id" {
  description = "DNS zone for .internal.io"
}

variable "automation_repo" {
  description = "repo holding the squid startup scripts"
  default     = "https://github.com/uc-cdis/cloud-automation.git"
}

variable "branch" {
  description = "branch to use in bootstrap script"
  default     = "master"
}

variable "extra_vars" {
  description = "additional variables to pass along with the bootstrapscript"
  default     = ["squid_image=master"]
}

variable "ssh_keys_repo" {
  description = "Optional repo containing squid authorized key files. Empty keeps using automation_repo/cloud-automation defaults."
  default     = ""
}

variable "ssh_admin_keys_file" {
  description = "Repo-relative or absolute path to admin authorized_keys file. Empty keeps bootstrap default."
  default     = ""
}

variable "ssh_user_keys_file" {
  description = "Repo-relative or absolute path to sftp user authorized_keys file. Empty keeps bootstrap default."
  default     = ""
}

variable "whitelist_repo" {
  description = "Optional repo containing squid whitelist files. Empty keeps using automation_repo/cloud-automation defaults."
  default     = ""
}

variable "ftp_whitelist_file" {
  description = "Repo-relative or absolute path to ftp_whitelist file. Empty keeps bootstrap default."
  default     = ""
}

variable "web_whitelist_file" {
  description = "Repo-relative or absolute path to web_whitelist file. Empty keeps bootstrap default."
  default     = ""
}

variable "web_wildcard_whitelist_file" {
  description = "Repo-relative or absolute path to web_wildcard_whitelist file. Empty keeps bootstrap default."
  default     = ""
}

variable "script_repo" {
  description = "Optional repo containing updatewhitelist and healthcheck scripts. Empty keeps using automation_repo/cloud-automation defaults."
  default     = ""
}

variable "updatewhitelist_script_file" {
  description = "Repo-relative or absolute path to updatewhitelist script. Empty keeps bootstrap default."
  default     = ""
}

variable "healthcheck_script_file" {
  description = "Repo-relative or absolute path to healthcheck script. Empty keeps bootstrap default."
  default     = ""
}

variable "deploy_ha_squid" {
  description = "Should this module be deployed"
  default     = true
}

variable "cluster_desired_capasity" {
  description = "Desired capasity for the ha squid proxy"
  default     = 2
}

variable "cluster_max_size" {
  description = "Max size of the autoscaling group"
  default     = 3
}

variable "cluster_min_size" {
  description = "Min size of the autoscaling group"
  default     = 1
}

variable "network_expansion" {
  description = "let k8s workers run on a /22 subnet"
  default     = false
}

variable "squid_depends_on" {
  default = ""
}

variable "activation_id" {
  default = ""
}

variable "customer_id" {
  default = ""
}

variable "slack_webhook" {
  default = ""
}

# the key that was used to encrypt the FIPS enabled AMI
# This is needed so ASG can decrypt the ami
variable "fips_ami_kms" {
  default = "arn:aws:kms:us-east-1:707767160287:key/mrk-697897f040ef45b0aa3cebf38a916f99"
}

variable "fips" {
  default = false
}

variable "ssm_parameter_name" {
  description = "If provided, use this SSM parameter to get the AMI ID at launch time"
  default     = ""
}

variable "ha_squid_single_instance" {
  description = "If true, deploy a single instance of squid instead in an autoscaling group"
  default     = false
}
