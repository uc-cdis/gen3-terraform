variable "vpc_name" {
  type = string
}


variable "subnet_name" {
  type = string
  default = "eks_private_0"
}

variable "base_image" {
  type = string
  default = "arn:aws:imagebuilder:us-east-1:aws:image/amazon-linux-2-ecs-optimized-kernel-5-x86/x.x.x"
}

variable image_scanning_enabled {
  type = bool
  default = true
}

variable imagebuilder_instance_profilename {
  type = string
  default = "EC2InstanceProfileForImageBuilder-nextflow"
}

variable pipeline_name {
  type = string
  default = "nextflow-fips"
}

variable recipe_name {
  type = string
  default = "nextflow-fips-recipe"
}

variable recipe_version {
  type = string
  default = "1.0.0"
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