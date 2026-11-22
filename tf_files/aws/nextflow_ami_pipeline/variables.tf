variable "vpc_name" {
  type = string
}

variable "region" {
  description = "AWS region where the pipeline resources will be deployed"
  type        = string
  default     = "us-east-1"
}


variable "subnet_name" {
  type = string
  default = "eks_private_0"
}

variable "base_image" {
  type        = string
  description = "Base image ARN for the pipeline. The default targets us-east-1; override with the equivalent ARN for your target region."
  default = "arn:aws:imagebuilder:us-east-1:aws:image/amazon-linux-2-ecs-optimized-kernel-5-x86/x.x.x"
}

variable image_scanning_enabled {
  type = bool
  default = true
}

variable "enable_ssm_fetch" {
  description = "Enable fetching SSM parameter"
  default = false
  type        = bool
}

variable ssm_parameter_name {
  description = "SSM parameter name"
  type        = string
  default     = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

variable pipeline_name {
  type = string
  default = "nextflow-fips"
}


variable public_ami_name {
  type = string
  default = "gen3-nextflow-{{ imagebuilder:buildDate }}"
}

variable "user_data" {
  type = string
  default = <<EOT
#!/bin/bash
# update yum repo
sudo yum update -y
# install and enable FIPS modules
sudo yum install -y dracut-fips openssl >> /opt/fips-install.log
sudo  dracut -f
# configure grub
sudo /sbin/grubby --update-kernel=ALL --args="fips=1"
EOT
}