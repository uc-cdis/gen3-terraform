resource "aws_launch_template" "this" {
  name_prefix   = var.name_prefix
  instance_type = var.instance_type
  image_id      = var.image_id
  key_name      = var.key_name != null && var.key_name != "" ? var.key_name : null

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    security_groups             = var.security_group_ids
  }

  user_data = sensitive(base64encode(var.user_data))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.volume_size
    }
  }

  dynamic "tag_specifications" {
    for_each = var.name_tag != "" ? [1] : []
    content {
      resource_type = "instance"
      tags          = merge({ Name = var.name_tag }, var.extra_tags)
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
