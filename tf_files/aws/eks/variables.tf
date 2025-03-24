
variable "vpc_name" {}

variable "vpc_id" {
  default = ""
}

variable "ec2_keyname" {
  default = "someone@uchicago.edu"
}

variable "instance_type" {
  default = "t3.large"
}

variable "jupyter_instance_type"{
  default = "t3.large"
}

variable "workflow_instance_type"{
  default = "t3.2xlarge"
}

variable "peering_cidr" {
  default = "10.128.0.0/20"
}

variable "secondary_cidr_block" {
  default = ""
}

variable "peering_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "users_policy" {}


variable "worker_drive_size" {
  default = 30
}

variable "eks_version" {
  default = "1.16"
}

variable "workers_subnet_size" {
  default = 24
}

variable "bootstrap_script" {
  default = "bootstrap-with-security-updates.sh"
}

variable "jupyter_bootstrap_script" {
  default = "bootstrap-with-security-updates.sh"
}

variable "kernel" {
  default = "N/A"
}

variable "jupyter_worker_drive_size" {
  default = 30
}

variable "workflow_bootstrap_script" {
  default =  "bootstrap.sh"
}

variable "workflow_worker_drive_size" {
  default = 30
}

variable "cidrs_to_route_to_gw" {
  default = []
}

variable "organization_name" {
  default = "Basic Services"
}

variable "jupyter_asg_desired_capacity" {
  default = 0
}

variable "jupyter_asg_max_size" {
  default = 10
}

variable "jupyter_asg_min_size" {
  default = 0
}

variable "workflow_asg_desired_capacity" {
  default = 0
}

variable "workflow_asg_max_size" {
  default = 50
}

variable "workflow_asg_min_size" {
  default = 0
}

variable "iam-serviceaccount" {
  default = true
}

variable "domain_test" {
  description = "url for the lambda function to check for the proxy"
  default     = "www.google.com"
}

variable "ha_squid" {
  description = "Is HA squid deployed?"
  default     = false
}

variable "deploy_workflow" {
  description = "Deploy workflow nodepool?"
  default     = false
}

variable "deploy_jupyter" {
  description = "Deploy workflow nodepool?"
  default     = true
}

variable "dual_proxy" {
  description = "Single instance and HA"
  default     = false
}

variable "single_az_for_jupyter" {
  description = "Jupyter notebooks on a single AZ"
  default     = false
}

variable "oidc_eks_thumbprint" {
  description = "Thumbprint for the AWS OIDC identity provider"
  default     = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  default     = "arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-topic"
}

variable "activation_id" {
  default = ""
}

variable "customer_id" {
  default = ""
}

# This controls whether or not we use FIPS enabled AMI's
variable "fips" {
  default = false
}

# the key that was used to encrypt the FIPS enabled AMI
# This is needed to ASG can decrypt the ami 
variable "fips_ami_kms" {
  default = "arn:aws:kms:us-east-1:707767160287:key/mrk-697897f040ef45b0aa3cebf38a916f99"
}

# This is the FIPS enabled AMI in cdistest account.
variable "fips_enabled_ami" {
  default = "ami-0de87e3680dcb13ec"
}

variable "availability_zones" {
  description = "AZ to be used by EKS nodes"
  default     = ["us-east-1a", "us-east-1c", "us-east-1d"]
}

variable "deploy_eks" {
  default = true
}

variable "scale_in_protection" {
  description = "set scale-in protection on ASG"
  default     = false
}

variable "ci_run" {
  description = "Don't run local provisioner commands meant for adminvm if running in CI"
  default     = false
}

variable "use_asg" {
  default = true
} 

variable "use_karpenter" {
  default = false
}

variable "karpenter_version" {
  default = "v0.24.0"
}

variable "eks_public_access" {
  default = "true"
}

variable "enable_vpc_endpoints" {
  default = true
}

variable "k8s_boostrap" {
  default = false
  description = "If set to true, creates resources for bootstrapping a kubernetes cluster (such as karpenter configs and helm releases)"
}

