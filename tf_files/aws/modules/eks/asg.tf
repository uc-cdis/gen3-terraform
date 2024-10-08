## Worker Node AutoScaling Group
# Now we have everything in place to create and manage EC2 instances that will serve as our worker nodes
# in the Kubernetes cluster. This setup utilizes an EC2 AutoScaling Group (ASG) rather than manually working with
# EC2 instances. This offers flexibility to scale up and down the worker nodes on demand when used in conjunction
# with AutoScaling policies (not implemented here).


# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-nodegroup.yaml

# See template.tf for more information about the bootstrap script


resource "aws_launch_template" "eks_launch_template" {
  name_prefix   = "eks-${var.vpc_name}"
  image_id      = local.ami
  instance_type = var.instance_type
  key_name      = var.ec2_keyname

  iam_instance_profile {
    name = aws_iam_instance_profile.eks_node_instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.eks_nodes_sg.id, aws_security_group.ssh.id]
  }

  user_data = sensitive(base64encode(templatefile("${path.module}/../../../../flavors/eks/${var.bootstrap_script}", {
    eks_ca          = aws_eks_cluster.eks_cluster.certificate_authority[0].data
    eks_endpoint    = aws_eks_cluster.eks_cluster.endpoint
    eks_region      = data.aws_region.current.name
    vpc_name        = var.vpc_name
    ssh_keys        = templatefile("${path.module}/../../../../files/authorized_keys/ops_team", {})
    nodepool        = "default"
    lifecycle_type  = "ONDEMAND"
    activation_id   = var.activation_id
    customer_id     = var.customer_id
  })))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.worker_drive_size
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "eks-${var.vpc_name}-node"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "eks_autoscaling_group" {
  count                   = var.use_asg ? 1 : 0
  service_linked_role_arn = aws_iam_service_linked_role.autoscaling.arn
  desired_capacity        = 2
  max_size                = 10
  min_size                = 2
  name                    = "eks-worker-node-${var.vpc_name}"
  vpc_zone_identifier     = flatten([aws_subnet.eks_private.*.id])

  launch_template {
    id      = aws_launch_template.eks_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Environment"
    value               = var.vpc_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "eks-${var.vpc_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.vpc_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = ""
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-type/eks"
    value               = ""
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/nodepool/default"
    value               = ""
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity, max_size, min_size]
  }
}
