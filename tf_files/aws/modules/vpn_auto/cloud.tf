locals {
  availability_zones = length(var.vpn_availability_zones) > 0 ? var.vpn_availability_zones : data.aws_availability_zones.available.names

  # The container renders these into openvpn.conf as `push "route <net> <mask>"`
  pushed_routes = join(";", var.pushed_routes)

  # Buckets the instance needs PKI access to. When adopting another VPN's PKI via
  # s3_prefix_override, that bucket has to be readable and writable too, otherwise the
  # recovery silently fails and the container builds a fresh CA that invalidates every
  # client config in circulation.
  override_pki_bucket = var.s3_prefix_override != "" ? split("/", var.s3_prefix_override)[0] : ""

  # Only worth having a bucket of our own when we are not adopting someone else's PKI
  create_pki_bucket = var.s3_prefix_override == ""

  # What the container is told to use, and what the IAM policy is written against
  pki_bucket_name = local.create_pki_bucket ? aws_s3_bucket.vpn_certs_and_files[0].bucket : local.override_pki_bucket
  pki_bucket_arns = distinct(compact([
    local.create_pki_bucket ? aws_s3_bucket.vpn_certs_and_files[0].arn : "",
    local.override_pki_bucket != "" ? "arn:aws:s3:::${local.override_pki_bucket}" : "",
  ]))

  # hostname=internal-lb-dns-name pairs, consumed by update-dnsmasq.sh on the host
  dnsmasq_overrides  = join(";", [for host, lb in var.dnsmasq_overrides : "${host}=${lb}"])
  dnsmasq_hosts_file = "/etc/dnsmasq.hosts"

  # The VPC resolver's link local address. Reachable from any subnet, and stable no
  # matter which VPC this lands in.
  upstream_dns = "169.254.169.253"

  dnsmasq_conf = templatefile("${path.module}/files/dnsmasq.conf", {
    hosts_file   = local.dnsmasq_hosts_file
    upstream_dns = local.upstream_dns
  })

  update_dnsmasq_service = templatefile("${path.module}/files/update-dnsmasq.service", {
    dnsmasq_overrides = local.dnsmasq_overrides
    hosts_file        = local.dnsmasq_hosts_file
    script_path       = "/usr/local/bin/update-dnsmasq.sh"
  })

  cloudwatch_config = jsonencode({
    agent = {
      run_as_user = "root"
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = "/var/log/messages"
              log_group_name  = aws_cloudwatch_log_group.vpn_log_group.name
              log_stream_name = "messages-{instance_id}"
            },
            {
              file_path       = "/var/log/secure"
              log_group_name  = aws_cloudwatch_log_group.vpn_log_group.name
              log_stream_name = "secure-{instance_id}"
            },
            {
              file_path       = "/var/log/bootstrapping_script.log"
              log_group_name  = aws_cloudwatch_log_group.vpn_log_group.name
              log_stream_name = "bootstrap-{instance_id}"
            },
            {
              # OpenVPN writes its client status table here, so this is the record of
              # who was connected when
              file_path       = "/etc/openvpn/openvpn-status.log"
              log_group_name  = aws_cloudwatch_log_group.vpn_log_group.name
              log_stream_name = "openvpn-status-{instance_id}"
            },
          ]
        }
      }
    }
  })
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
  name               = "${var.env_vpn_name}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = aws_subnet.vpn_pub[*].id
  # On by default: this is how people get into the environment, so it should not be
  # removable by accident. Turn it off for throwaway stacks, otherwise destroy fails
  # and the subnets cannot be released until the flag is flipped by hand.
  enable_deletion_protection       = var.enable_deletion_protection
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

# Serves the QR codes used to enroll TOTP
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
# instead of generating a new CA and invalidating every client config.
#
# Not created when s3_prefix_override is set. In that case the stack reads another
# VPN's PKI read only and never writes, so its own bucket would be created and then
# sit empty forever.
resource "aws_s3_bucket" "vpn_certs_and_files" {
  count  = local.create_pki_bucket ? 1 : 0
  bucket = "vpn-certs-and-files-${var.env_vpn_name}"

  tags = {
    Name        = "vpn-certs-and-files-${var.env_vpn_name}"
    Environment = var.env_vpn_name
    Purpose     = "VPN PKI and client configs"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vpn_certs_and_files" {
  count  = local.create_pki_bucket ? 1 : 0
  bucket = aws_s3_bucket.vpn_certs_and_files[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "vpn_certs_and_files" {
  count  = local.create_pki_bucket ? 1 : 0
  bucket = aws_s3_bucket.vpn_certs_and_files[0].id

  versioning_configuration {
    status = "Enabled"
  }
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

  # Everything the VPN needs lives in the image and the units below. No repo is
  # cloned at boot, so a stale branch reference cannot break a replacement instance.
  user_data = base64encode(templatefile("${path.module}/files/userdata.sh.tpl", {
    env_cloud_name         = var.env_cloud_name
    env_vpn_name           = var.env_vpn_name
    vpn_image              = "quay.io/cdis/openvpn:${var.vpn_image_tag}"
    cwl_group              = aws_cloudwatch_log_group.vpn_log_group.name
    csoc_vpn_subnet        = var.csoc_vpn_subnet
    csoc_vm_subnet         = var.csoc_vm_subnet
    pushed_routes          = local.pushed_routes
    s3_prefix_override     = var.s3_prefix_override
    client_ca_mode         = var.client_ca_mode
    acm_pca_ca_arn         = var.acm_pca_ca_arn
    s3_bucket              = local.pki_bucket_name
    account_id             = data.aws_caller_identity.current.account_id
    region                 = data.aws_region.current.name
    dnsmasq_hosts_file     = local.dnsmasq_hosts_file
    cloudwatch_config      = local.cloudwatch_config
    dnsmasq_conf           = local.dnsmasq_conf
    update_dnsmasq_script  = file("${path.module}/files/update-dnsmasq.sh")
    update_dnsmasq_service = local.update_dnsmasq_service
    update_dnsmasq_timer   = file("${path.module}/files/update-dnsmasq.timer")
  }))

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
