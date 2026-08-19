locals {
  availability_zones = length(var.vpn_availability_zones) > 0 ? var.vpn_availability_zones : data.aws_availability_zones.available.names

  # The container renders these into openvpn.conf as `push "route <net> <mask>"`
  pushed_routes = join(";", var.pushed_routes)

  # hostname=internal-lb-dns-name pairs, consumed by update-dnsmasq.sh
  dnsmasq_overrides = join(";", [for host, lb in var.dnsmasq_overrides : "${host}=${lb}"])
}

resource "aws_cloudwatch_log_group" "vpn_log_group" {
  name              = var.cwl_group_name
  retention_in_days = 1827

  tags = {
    Environment  = var.env_vpn_name
    Organization = var.organization_name
  }
}

## ----- IAM -------

resource "aws_iam_role" "vpn_role" {
  name = "${var.env_vpn_name}_role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "vpn_policy" {
  name   = "${var.env_vpn_name}_policy"
  role   = aws_iam_role.vpn_role.id
  policy = data.aws_iam_policy_document.vpn_policy_document.json
}

# Session Manager access, so we do not depend on ssh to get onto these boxes
resource "aws_iam_role_policy_attachment" "vpn_ssm" {
  role       = aws_iam_role.vpn_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "vpn_role_profile" {
  name = "${var.env_vpn_name}_vpn_role_profile"
  role = aws_iam_role.vpn_role.id
}

## ----- Networking -------

resource "aws_subnet" "vpn_pub" {
  count             = length(local.availability_zones)
  vpc_id            = var.env_vpc_id
  cidr_block        = cidrsubnet(var.vpn_server_subnet, 3, count.index)
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name         = "${var.env_vpn_name}_pub_${count.index}"
    Environment  = var.env_vpn_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = [availability_zone]
  }
}

resource "aws_route_table_association" "vpn" {
  count          = length(aws_subnet.vpn_pub)
  subnet_id      = aws_subnet.vpn_pub[count.index].id
  route_table_id = var.env_pub_subnet_routetable_id
}

## ----- Load balancer -------

resource "aws_lb" "vpn_nlb" {
  name                             = "${var.env_vpn_name}-nlb"
  internal                         = false
  load_balancer_type               = "network"
  subnets                          = aws_subnet.vpn_pub[*].id
  enable_deletion_protection       = true
  enable_cross_zone_load_balancing = true

  tags = {
    Environment  = var.env_vpn_name
    Organization = var.organization_name
  }
}

# OpenVPN itself
resource "aws_lb_target_group" "vpn_tcp" {
  name     = "${var.env_vpn_name}-tcp-tg"
  port     = 1194
  protocol = "TCP"
  vpc_id   = var.env_vpc_id

  tags = {
    Environment  = var.env_vpn_name
    Organization = var.organization_name
  }
}

resource "aws_lb_listener" "vpn_tcp" {
  load_balancer_arn = aws_lb.vpn_nlb.arn
  port              = "1194"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.vpn_tcp.arn
    type             = "forward"
  }
}

# lighttpd, serves the QR codes used to enroll TOTP
resource "aws_lb_target_group" "vpn_qr" {
  name     = "${var.env_vpn_name}-qr-tg"
  port     = 443
  protocol = "TCP"
  vpc_id   = var.env_vpc_id

  tags = {
    Environment  = var.env_vpn_name
    Organization = var.organization_name
  }
}

resource "aws_lb_listener" "vpn_qr" {
  load_balancer_arn = aws_lb.vpn_nlb.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.vpn_qr.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "vpn_ssh" {
  name     = "${var.env_vpn_name}-ssh-tg"
  port     = 22
  protocol = "TCP"
  vpc_id   = var.env_vpc_id

  tags = {
    Environment  = var.env_vpn_name
    Organization = var.organization_name
  }
}

resource "aws_lb_listener" "vpn_ssh" {
  load_balancer_arn = aws_lb.vpn_nlb.arn
  port              = "22"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.vpn_ssh.arn
    type             = "forward"
  }
}

## ----- Certs bucket -------

# The PKI gets pushed here so a replacement instance recovers the existing certs
# instead of generating a new CA and invalidating every client config
resource "aws_s3_bucket" "vpn_certs_and_files" {
  bucket = "vpn-certs-and-files-${var.env_vpn_name}"

  tags = {
    Name        = "vpn-certs-and-files-${var.env_vpn_name}"
    Environment = var.env_vpn_name
    Purpose     = "VPN PKI and client configs"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vpn_certs_and_files" {
  bucket = aws_s3_bucket.vpn_certs_and_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "vpn_certs_and_files" {
  bucket = aws_s3_bucket.vpn_certs_and_files.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "vpn_certs_and_files" {
  bucket = aws_s3_bucket.vpn_certs_and_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

## ----- Compute -------

resource "aws_launch_template" "vpn" {
  name_prefix   = "${var.env_vpn_name}-lt"
  instance_type = var.vpn_instance_type
  image_id      = var.ssm_parameter_name != "" ? var.ssm_parameter_name : data.aws_ami.vpn_ami.id
  key_name      = var.ssh_key_name != "" ? var.ssh_key_name : null

  iam_instance_profile {
    name = aws_iam_instance_profile.vpn_role_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.vpn_in.id, aws_security_group.vpn_out.id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.vpn_instance_drive_size
      encrypted   = true
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    # The container reads its own private ip from here to push DNS to clients,
    # and hops through the docker bridge on the way
    http_tokens                 = "optional"
    http_put_response_hop_limit = 2
  }

  # Everything the VPN needs lives in the image. No repo is cloned at boot, so a
  # stale branch reference can never break a replacement instance again.
  user_data = base64encode(<<-EOF
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="BOUNDARY"

    --BOUNDARY
    Content-Type: text/x-shellscript; charset="us-ascii"

    #!/bin/bash
    set -euo pipefail
    exec > >(tee /var/log/bootstrapping_script.log) 2>&1

    hostnamectl set-hostname ${var.env_cloud_name}
    echo "127.0.1.1 ${var.env_cloud_name}" >> /etc/hosts

    dnf update -y
    dnf install -y docker amazon-cloudwatch-agent

    # The VPN needs to forward between the tun device and the VPC
    cat > /etc/sysctl.d/99-openvpn.conf <<'SYSCTL'
    net.ipv4.ip_forward = 1
    SYSCTL
    sysctl --system

    systemctl enable --now docker

    cat > /etc/cloudwatch-config.json <<'CWA'
    {
      "agent": { "run_as_user": "root" },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/messages",
                "log_group_name": "${aws_cloudwatch_log_group.vpn_log_group.name}",
                "log_stream_name": "messages-{instance_id}"
              },
              {
                "file_path": "/var/log/secure",
                "log_group_name": "${aws_cloudwatch_log_group.vpn_log_group.name}",
                "log_stream_name": "secure-{instance_id}"
              },
              {
                "file_path": "/var/log/bootstrapping_script.log",
                "log_group_name": "${aws_cloudwatch_log_group.vpn_log_group.name}",
                "log_stream_name": "bootstrap-{instance_id}"
              },
              {
                "file_path": "/etc/openvpn/openvpn-status.log",
                "log_group_name": "${aws_cloudwatch_log_group.vpn_log_group.name}",
                "log_stream_name": "openvpn-status-{instance_id}"
              }
            ]
          }
        }
      }
    }
    CWA
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -c file:/etc/cloudwatch-config.json -s

    mkdir -p /etc/openvpn

    # Run the VPN as a systemd unit so docker restarts and instance reboots both
    # come back cleanly, and so the iptables rules get reapplied every start
    cat > /etc/systemd/system/openvpn-container.service <<'UNIT'
    [Unit]
    Description=OpenVPN server container
    After=docker.service network-online.target
    Requires=docker.service
    Wants=network-online.target

    [Service]
    Restart=always
    RestartSec=10
    TimeoutStartSec=0
    ExecStartPre=-/usr/bin/docker rm -f openvpn
    ExecStartPre=/usr/bin/docker pull quay.io/cdis/openvpn:${var.vpn_image_tag}
    ExecStart=/usr/bin/docker run --rm --name openvpn \
      --network host \
      --cap-add NET_ADMIN \
      --device /dev/net/tun \
      -v /etc/openvpn:/etc/openvpn \
      -e VPN_NLB_NAME=${var.env_vpn_name} \
      -e CLOUD_NAME=${var.env_cloud_name} \
      -e CWL_GROUP=${aws_cloudwatch_log_group.vpn_log_group.name} \
      -e CSOC_VPN_SUBNET=${var.csoc_vpn_subnet} \
      -e CSOC_VM_SUBNET=${var.csoc_vm_subnet} \
      -e PUSHED_ROUTES='${local.pushed_routes}' \
      -e DNSMASQ_OVERRIDES='${local.dnsmasq_overrides}' \
      -e S3_BUCKET=${aws_s3_bucket.vpn_certs_and_files.bucket} \
      -e ACCOUNT_ID=${data.aws_caller_identity.current.account_id} \
      -e AWS_DEFAULT_REGION=${data.aws_region.current.name} \
      quay.io/cdis/openvpn:${var.vpn_image_tag}
    ExecStop=/usr/bin/docker stop openvpn

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable --now openvpn-container.service

    --BOUNDARY--
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name         = var.env_vpn_name
      Environment  = var.env_vpn_name
      Organization = var.organization_name
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Lets the ASG use KMS keys from other accounts if we ever need an encrypted custom AMI
resource "aws_iam_service_linked_role" "vpn_autoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  custom_suffix    = var.env_vpn_name

  lifecycle {
    ignore_changes = [custom_suffix]
  }
}

resource "aws_autoscaling_group" "vpn" {
  name                    = "${var.env_vpn_name}_autoscaling_grp"
  service_linked_role_arn = aws_iam_service_linked_role.vpn_autoscaling.arn
  desired_capacity        = var.cluster_desired_capacity
  min_size                = var.cluster_min_size
  max_size                = var.cluster_max_size
  vpc_zone_identifier     = aws_subnet.vpn_pub[*].id
  target_group_arns       = [aws_lb_target_group.vpn_tcp.arn, aws_lb_target_group.vpn_qr.arn, aws_lb_target_group.vpn_ssh.arn]
  depends_on              = [aws_route_table_association.vpn]

  launch_template {
    id      = aws_launch_template.vpn.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.env_vpn_name}_autoscaling_grp_member"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.env_vpn_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Organization"
    value               = var.organization_name
    propagate_at_launch = true
  }
}

## ----- Security groups -------

resource "aws_security_group" "vpn_in" {
  name        = "${var.env_vpn_name}-vpn_in"
  description = "Inbound access to the VPN endpoint"
  vpc_id      = var.env_vpc_id

  # OpenVPN. Has to be open, this is how people get in
  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # QR codes for TOTP enrollment
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ssh stays internal. Use Session Manager to get on these boxes from elsewhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = [var.csoc_vm_subnet]
  }

  tags = {
    Environment  = var.env_vpn_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = [description]
  }
}

resource "aws_security_group" "vpn_out" {
  name        = "${var.env_vpn_name}-vpn_out"
  description = "security group that allows outbound traffic"
  vpc_id      = var.env_vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = var.env_vpn_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = [description]
  }
}

## ----- DNS -------

# Defaults to a name derived from env_vpn_name, which is what you want while this runs
# green alongside the old stack. To cut over, set dns_record_name to the hostname clients
# already use and apply. Keep the TTL low until the cutover has settled.
resource "aws_route53_record" "vpn" {
  count   = var.manage_dns_record ? 1 : 0
  zone_id = var.csoc_planx_dns_zone_id
  name    = var.dns_record_name != "" ? var.dns_record_name : var.env_vpn_name
  type    = "CNAME"
  ttl     = var.dns_record_ttl
  records = [aws_lb.vpn_nlb.dns_name]
}
