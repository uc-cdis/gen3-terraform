################################################################################
# Karpenter
################################################################################

module "karpenter" {
  count   = var.use_karpenter ? 1 : 0
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"

  create_iam_role        = false
  iam_role_arn           = aws_iam_role.eks_node_role.arn
  cluster_name           = aws_eks_cluster.eks_cluster.id
  irsa_oidc_provider_arn = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer

  #policies = {
  #  AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  #}
}

resource "aws_eks_fargate_profile" "karpenter" {
  count                  = var.use_karpenter ? 1 : 0
  cluster_name           = aws_eks_cluster.eks_cluster.name
  fargate_profile_name   = "karpenter"
  pod_execution_role_arn = aws_iam_role.karpenter.0.arn
  subnet_ids             = local.eks_priv_subnets

  selector {
    namespace = "karpenter"
  }
}

resource "aws_iam_role" "karpenter" {
  count = var.use_karpenter ? 1 : 0
  name  = "${var.vpc_name}-karpenter-fargate-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "karpenter-role-policy" {
  count      = var.use_karpenter ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.karpenter.0.name
}

resource "helm_release" "karpenter" {
  count               = var.use_karpenter ? 1 : 0
  namespace           = "karpenter"
  create_namespace    = true
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = var.karpenter_version

  set {
    name  = "settings.aws.clusterName"
    value = aws_eks_cluster.eks_cluster.id
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = aws_eks_cluster.eks_cluster.endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.0.irsa_arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.eks_node_instance_profile.id
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter.0.queue_name
  }
}

resource "kubectl_manifest" "karpenter_provisioner" {
  count   = var.use_karpenter ? 1 : 0

  yaml_body = <<-YAML
    ---
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      # Allow for spot and on demand instances
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand", "spot"]
        - key: kubernetes.io/arch
          operator: In
          values:
          - amd64
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values:
          - c
          - m
          - r
          - t       
      # Set a limit of 1000 vcpus
      limits:
        resources:
          cpu: 1000
      # Use the default node template
      providerRef:
        name: default
      # Allow pods to be rearranged
      consolidation:
        enabled: true
      # Kill nodes after 30 days to ensure they stay up to date
      ttlSecondsUntilExpired: 2592000
    ---
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: jupyter
    spec:
      # Only allow on demand instance        
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: kubernetes.io/arch
          operator: In
          values:
          - amd64
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values:
          - c
          - m
          - r
          - t       
      # Set a taint for jupyter pods
      taints:
        - key: role
          value: jupyter
          effect: NoSchedule       
      labels:
        role: jupyter
      # Set a limit of 1000 vcpus      
      limits:
        resources:
          cpu: 1000
      # Use the jupyter node template      
      providerRef:
        name: jupyter
      # Allow pods to be rearranged
      consolidation:
        enabled: true
      # Kill nodes after 30 days to ensure they stay up to date
      ttlSecondsUntilExpired: 2592000
    ---
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: workflow
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: kubernetes.io/arch
          operator: In
          values:
          - amd64
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values:
          - c
          - m
          - r
          - t       
      taints:
        - key: role
          value: workflow
          effect: NoSchedule
      labels:
        role: workflow
      limits:
        resources:
          cpu: 1000
      providerRef:
        name: workflow
      # Allow pods to be rearranged
      consolidation:
        enabled: true
      # Kill nodes after 30 days to ensure they stay up to date
      ttlSecondsUntilExpired: 2592000    
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_template" {
  count   = var.use_karpenter ? 1 : 0

  yaml_body = <<-YAML
    ---
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${var.vpc_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${var.vpc_name}
      tags:
        karpenter.sh/discovery: ${var.vpc_name}
        Environment: ${var.vpc_name}
        Name: eks-${var.vpc_name}-karpenter
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 2
        httpTokens: optional
      userData: |
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="BOUNDARY"

        --BOUNDARY
        Content-Type: text/x-shellscript; charset="us-ascii"

        #!/bin/bash -xe
        instanceId=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)
        curl https://raw.githubusercontent.com/uc-cdis/cloud-automation/master/files/authorized_keys/ops_team >> /home/ec2-user/.ssh/authorized_keys
        aws ec2 create-tags --resources $instanceId --tags 'Key="instanceId",Value='$instanceId''
        curl https://raw.githubusercontent.com/uc-cdis/cloud-automation/master/files/authorized_keys/ops_team >> /home/ec2-user/.ssh/authorized_keys

        sysctl -w fs.inotify.max_user_watches=12000

        sudo yum update -y
        sudo yum install -y dracut-fips openssl >> /opt/fips-install.log
        sudo  dracut -f
        # configure grub
        sudo /sbin/grubby --update-kernel=ALL --args="fips=1"

        --BOUNDARY
        Content-Type: text/cloud-config; charset="us-ascii"

        power_state:
          delay: now
          mode: reboot
          message: Powering off
          timeout: 2
          condition: true


        --BOUNDARY--
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: ${var.worker_drive_size}Gi
            volumeType: gp2
            encrypted: true
            deleteOnTermination: true
    ---
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: jupyter
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${var.vpc_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${var.vpc_name}
      tags:
        Environment: ${var.vpc_name}
        Name: eks-${var.vpc_name}-jupyter-karpenter
        karpenter.sh/discovery: ${var.vpc_name}
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 2
        httpTokens: optional
      userData: |
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="BOUNDARY"

        --BOUNDARY
        Content-Type: text/x-shellscript; charset="us-ascii"

        #!/bin/bash -xe
        instanceId=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)
        curl https://raw.githubusercontent.com/uc-cdis/cloud-automation/master/files/authorized_keys/ops_team >> /home/ec2-user/.ssh/authorized_keys
        aws ec2 create-tags --resources $instanceId --tags 'Key="instanceId",Value='$instanceId''
        curl https://raw.githubusercontent.com/uc-cdis/cloud-automation/master/files/authorized_keys/ops_team >> /home/ec2-user/.ssh/authorized_keys

        sysctl -w fs.inotify.max_user_watches=12000

        sudo yum update -y
        sudo yum install -y dracut-fips openssl >> /opt/fips-install.log
        sudo  dracut -f
        # configure grub
        sudo /sbin/grubby --update-kernel=ALL --args="fips=1"

        --BOUNDARY
        Content-Type: text/cloud-config; charset="us-ascii"

        power_state:
          delay: now
          mode: reboot
          message: Powering off
          timeout: 2
          condition: true

        --BOUNDARY--
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: ${var.jupyter_worker_drive_size}Gi
            volumeType: gp2
            encrypted: true
            deleteOnTermination: true 
    ---
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: workflow
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${var.vpc_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${var.vpc_name}
      tags:
        Environment: ${var.vpc_name}
        Name: eks-${var.vpc_name}-workflow-karpenter
        karpenter.sh/discovery: ${var.vpc_name}
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 2
        httpTokens: optional
      userData: |
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="BOUNDARY"

        --BOUNDARY
        Content-Type: text/x-shellscript; charset="us-ascii"

        #!/bin/bash -xe
        instanceId=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)
        curl https://raw.githubusercontent.com/uc-cdis/cloud-automation/master/files/authorized_keys/ops_team >> /home/ec2-user/.ssh/authorized_keys
        aws ec2 create-tags --resources $instanceId --tags 'Key="instanceId",Value='$instanceId''
        curl https://raw.githubusercontent.com/uc-cdis/cloud-automation/master/files/authorized_keys/ops_team >> /home/ec2-user/.ssh/authorized_keys

        sysctl -w fs.inotify.max_user_watches=12000

        sudo yum update -y
        sudo yum install -y dracut-fips openssl >> /opt/fips-install.log
        sudo  dracut -f
        # configure grub
        sudo /sbin/grubby --update-kernel=ALL --args="fips=1"

        --BOUNDARY
        Content-Type: text/cloud-config; charset="us-ascii"

        power_state:
          delay: now
          mode: reboot
          message: Powering off
          timeout: 2
          condition: true

        --BOUNDARY--
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: ${var.workflow_worker_drive_size}Gi
            volumeType: gp2
            encrypted: true
            deleteOnTermination: true     
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}