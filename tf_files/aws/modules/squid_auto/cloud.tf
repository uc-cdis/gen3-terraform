locals{
  cidrs  = var.secondary_cidr_block != "" ? [var.env_vpc_cidr, var.peering_cidr, var.secondary_cidr_block] : [var.env_vpc_cidr, var.peering_cidr]
  cidrs2 = var.secondary_cidr_block != "" ? [var.env_vpc_cidr, var.secondary_cidr_block] : [var.env_vpc_cidr]
  bootstrap_script = var.ha_squid_single_instance ? "squid_running_on_docker_single_instance.sh" : var.bootstrap_script
}

#Launching the public subnets for the squid VMs
# If squid is launched in PROD 172.X.Y+5.0/24 subnet is used; For QA/DEV 172.X.Y+1.0/24 subnet is used
# The value of var.environment is supplied as a user variable - 1 for PROD and 0 for QA/DEV

# FOR PROD ENVIRONMENT:

resource "aws_subnet" "squid_pub0" {
  count             = length(var.squid_availability_zones)
  vpc_id            = var.env_vpc_id
  cidr_block        = var.network_expansion ? cidrsubnet(var.squid_proxy_subnet,2,count.index) : cidrsubnet(var.squid_proxy_subnet,3,count.index )
  availability_zone = var.squid_availability_zones[count.index]
  tags              = tomap({"Name" = "${var.env_squid_name}_pub${count.index}", "Organization" = var.organization_name, "Environment" = var.env_squid_name})
}

# Instance profile role and policies, we need the proxy to be able to talk to cloudwatchlogs groups
#
##########################
resource "aws_iam_role" "squid-auto_role" {
  name               = "${var.env_squid_name}_role"
  path               = "/"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "squid_policy" {
  name   = "${var.env_squid_name}_policy"
  policy = data.aws_iam_policy_document.squid_policy_document.json
  role   = aws_iam_role.squid-auto_role.id
}

# Amazon SSM Policy
resource "aws_iam_role_policy_attachment" "eks-policy-AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.squid-auto_role.id
}

resource "aws_iam_instance_profile" "squid-auto_role_profile" {
  name = "${var.env_vpc_name}_squid-auto_role_profile"
  role = aws_iam_role.squid-auto_role.id
}

##################


resource "aws_route_table_association" "squid_auto0" {
  count          = length(var.squid_availability_zones)
  subnet_id      = aws_subnet.squid_pub0.*.id[count.index]
  route_table_id = var.main_public_route
}


# Auto scaling group for squid auto
resource "aws_launch_template" "squid_auto" {
  name_prefix   = "${var.env_squid_name}-lt"
  instance_type = var.squid_instance_type
  image_id      = data.aws_ami.public_squid_ami.id
  key_name      = var.ssh_key_name != "" ? var.ssh_key_name : null

  iam_instance_profile {
    name = aws_iam_instance_profile.squid-auto_role_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.squidauto_in.id, aws_security_group.squidauto_out.id]
  }

  user_data = sensitive(base64encode( <<EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
EC2_INSTANCE_ID="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`"
aws ec2 modify-instance-attribute --no-source-dest-check --instance-id $EC2_INSTANCE_ID --region ${data.aws_region.current.name}
DISTRO=$(awk -F '[="]*' '/^NAME/ { print $2 }' < /etc/os-release)
USER="ubuntu"
if [[ $DISTRO == "Amazon Linux" ]]; then
  USER="ec2-user"
  if [[ $(awk -F '[="]*' '/^VERSION_ID/ { print $2 }' < /etc/os-release) == "2023" ]]; then
    DISTRO="al2023"
  fi
fi
(
  if [[ $DISTRO == "Amazon Linux" ]]; then
    sudo yum update -y
    sudo yum install git lsof openssl rsync -y
    echo "0 3 * * * root yum update --security -y" | sudo tee /etc/cron.d/security-updates
  elif [[ $DISTRO == "al2023" ]]; then
    sudo dnf update -y
    sudo dnf install git rsync lsof docker crypto-policies crypto-policies-scripts -y
  fi

  USER_HOME="/home/$USER"
  CLOUD_AUTOMATION="$USER_HOME/cloud-automation"
  cd $USER_HOME
  if [[ ! -z "${var.slack_webhook}" ]]; then
    echo "${var.slack_webhook}" > /slackWebhook
  fi
  git clone https://github.com/uc-cdis/cloud-automation.git
  cd $CLOUD_AUTOMATION
  git pull

  # This is needed temporarily for testing purposes ; before merging the code to master
  if [ "${var.branch}" != "master" ];
  then
    git checkout "${var.branch}"
    git pull
  fi
  chown -R $USER. $CLOUD_AUTOMATION

  echo "127.0.1.1 ${var.env_squid_name}" | tee --append /etc/hosts
  hostnamectl set-hostname ${var.env_squid_name}
  if [[ $DISTRO == "Ubuntu" ]]; then
    apt -y update
    DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade

    apt autoremove -y
    apt clean
    apt autoclean
  fi
  cd $USER_HOME

  bash "${var.bootstrap_path}${local.bootstrap_script}" "cwl_group=${var.env_log_group};${join(";",var.extra_vars)}" 2>&1
  cd $CLOUD_AUTOMATION
  git checkout master
) > /var/log/bootstrapping_script.log
--BOUNDARY--
EOF
  ))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.squid_instance_drive_size
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.env_squid_name}"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "null_resource" "service_depends_on" {
  triggers = {
    # This reference creates an implicit dependency on the variable, and thus
    # transitively on everything the variable itself depends on.
    deps = jsonencode(var.squid_depends_on)
  }
}

# Create a new iam service linked role that we can grant access to KMS keys in other accounts
# Needed if we need to bring up custom AMI's that have been encrypted using a kms key
resource "aws_iam_service_linked_role" "squidautoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  custom_suffix    = "${var.env_vpc_name}_squid"

  lifecycle {
    ignore_changes = [custom_suffix]
  }
}

# Remember to grant access to the account in the KMS key policy too
resource "aws_kms_grant" "kms" {
  count             = var.fips ? 1 : 0
  name              = "kms-cmk-eks"
  key_id            = var.fips_ami_kms
  grantee_principal = aws_iam_service_linked_role.squidautoscaling.arn
  operations        = ["Encrypt", "Decrypt", "ReEncryptFrom", "ReEncryptTo", "GenerateDataKey", "GenerateDataKeyWithoutPlaintext", "DescribeKey", "CreateGrant"]
}

resource "aws_autoscaling_group" "squid_auto" {
  name                    = var.env_squid_name
  service_linked_role_arn = aws_iam_service_linked_role.squidautoscaling.arn
  desired_capacity        = var.ha_squid_single_instance ? 1 : var.cluster_desired_capasity
  max_size                = var.ha_squid_single_instance ? 1 : var.cluster_max_size
  min_size                = var.ha_squid_single_instance ? 1 : var.cluster_min_size
  vpc_zone_identifier     = aws_subnet.squid_pub0.*.id
  depends_on              = [null_resource.service_depends_on, aws_route_table_association.squid_auto0]

  launch_template {
    id      = aws_launch_template.squid_auto.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.env_squid_name}-grp-member"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.organization_name
    propagate_at_launch = true
  }
}


# Security groups for the Commons squid proxy

resource "aws_security_group" "squidauto_in" {
  name        = "${var.env_squid_name}-squidauto_in"
  description = "security group that only enables ssh from VPC nodes and CSOC"
  vpc_id      = var.env_vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    #
    # Do not do this - fence may ssh-bridge out for sftp access
    #
    cidr_blocks  = local.cidrs
  }

  tags = {
    Environment  = var.env_squid_name
    Organization = var.organization_name
  }

  ingress {
    from_port    = 3128
    to_port      = 3128
    protocol     = "TCP"
    cidr_blocks  = local.cidrs
  }

  ingress {
    from_port    = 80
    to_port      = 80
    protocol     = "TCP"
    cidr_blocks  = local.cidrs2
  }

  ingress {
    from_port    = 443
    to_port      = 443
    protocol     = "TCP"
    cidr_blocks  = local.cidrs2
  }

  lifecycle {
    ignore_changes = [description]
  }
}


resource "aws_security_group" "squidauto_out" {
  name        = "${var.env_squid_name}-squidauto_out"
  description = "security group that allow outbound traffics"
  vpc_id      = var.env_vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = var.env_squid_name
    Organization = var.organization_name
  }
}
