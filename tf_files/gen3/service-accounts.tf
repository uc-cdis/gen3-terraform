resource "aws_iam_role" "audit-role" {
  count = var.audit_enabled ? 1 : 0
  name = "${var.vpc_name}-${var.namespace}-audit-sa"
  description = "Role for ES proxy service account for ${var.vpc_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Sid = ""
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider_arn}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_arn}:sub" = [
              "system:serviceaccount:${var.namespace}:audit-sa"
            ]
            "${var.oidc_provider_arn}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  path = "/gen3-service/"
}

resource "aws_iam_role_policy" "audit-role-policy" {
  name = "audit-role-policy"
  role = aws_iam_role.audit-role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:GetQueueAttributes",
          "sqs:DeleteMessage"
        ]
        Effect   = "Allow"
        Resource = [
          module.audit-sqs.sqs-arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "fence-role" {
  count = var.fence_enabled ? 1 : 0
  name = "${var.vpc_name}-${var.namespace}-fence-sa"
  description = "Role for ES proxy service account for ${var.vpc_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Sid = ""
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider_arn}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_arn}:sub" = [
              "system:serviceaccount:${var.namespace}:fence-sa"
            ]
            "${var.oidc_provider_arn}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  path = "/gen3-service/"
}

resource "aws_iam_role_policy" "fence-role-policy" {
  name = "fence-role-policy"
  role = aws_iam_role.fence-role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:SendMessage"
        ]
        Effect   = "Allow"
        Resource = [
          module.audit-sqs.sqs-arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "gitops-role" {
  name = "${var.vpc_name}-${var.namespace}-gitops-sa"
  description = "Role for gitops service account for ${var.vpc_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Sid = ""
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider_arn}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_arn}:sub" = [
              "system:serviceaccount:${var.namespace}:gitops-sa"
            ]
            "${var.oidc_provider_arn}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  path = "/gen3-service/"
}

resource "aws_iam_role_policy" "gitops-role-policy" {
  name = "gitops-role-policy"
  role = aws_iam_role.gitops-role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:List*",
          "s3:Get*"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::dashboard-${data.aws_caller_identity.current.account_id}-${var.vpc_name}-gen3/*",
          "arn:aws:s3:::dashboard-${data.aws_caller_identity.current.account_id}-${var.vpc_name}-gen3"
        ]
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::dashboard-${data.aws_caller_identity.current.account_id}-${var.vpc_name}-gen3/*"
      }
    ]
  })
}

resource "aws_iam_role" "hatchery-role" {
  count = var.hatchery_enabled ? 1 : 0
  name = "${var.vpc_name}-${var.namespace}-hatchery-sa"
  description = "Role for ES proxy service account for ${var.vpc_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Sid = ""
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider_arn}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_arn}:sub" = [
              "system:serviceaccount:${var.namespace}:hatchery-sa"
            ]
            "${var.oidc_provider_arn}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  path = "/gen3-service/"
}

resource "aws_iam_role_policy" "hatchery-role-policy" {
  name = "hatchery-role-policy"
  role = aws_iam_role.hatchery-role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:iam::*:role/csoc_adminvm*"
        ]
      },
      {
        Action = [
          "ec2:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "hatchery-role-policy-attachment" {
  count = var.hatchery_enabled ? 1 : 0
  role = aws_iam_role.hatchery-role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSResourceAccessManagerFullAccess"
}

resource "aws_iam_role" "manifestservice-role" {
  count = var.manifestservice_enabled ? 1 : 0
  name = "${var.vpc_name}-${var.namespace}-manifestservice-sa"
  description = "Role for manifestservice service account for ${var.vpc_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Sid = ""
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider_arn}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_arn}:sub" = [
              "system:serviceaccount:${var.namespace}:manifestservice-sa"
            ]
            "${var.oidc_provider_arn}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  path = "/gen3-service/"
}

resource "aws_iam_role_policy" "manifestservice-role-policy" {
  name = "manifestservice-role-policy"
  role = aws_iam_role.manifestservice-role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:List*",
          "s3:Get*"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::manifestservice-${var.vpc_name}-${var.namespace}/*",
          "arn:aws:s3:::manifestservice-${var.vpc_name}-${var.namespace}"
        ]
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::manifestservice-${var.vpc_name}-${var.namespace}/*"
      }
    ]   
  })
}

resource "aws_iam_role" "aws-load-balancer-controller-role" {
  count = var.namespace == "default" ? 1 : 0
  name = "${var.vpc_name}-aws-load-balancer-controller-sa"
  description = "Role for ALB controller service account for ${var.vpc_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Sid = ""
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider_arn}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_arn}:sub" = [
              "system:serviceaccount:kube-system:aws-load-balancer-controller"
            ]
            "${var.oidc_provider_arn}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  path = "/gen3-service/"
}


resource "aws_iam_role_policy" "aws-load-balancer-role-policy" {
  count = var.namespace == "default" ? 1 : 0
  name = "aws-load-balancer-controller-role-policy"
  role = aws_iam_role.aws-load-balancer-controller-role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "iam:createServiceLinkedRole"
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:GetSecurityGroupsForVpc",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:AddTags"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ec2:CreateSecurityGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ec2:CreateTags"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          Null = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        ]
      },
      {
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          Null = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        Action = [
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "external-secrets-role" {
  count = var.namespace == "default" || var.deploy_external_secrets  ? 1 : 0
  name = "${var.vpc_name}-${var.namespace}-external-secrets-sa"
  description = "Role for external-secrets service account for ${var.vpc_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Sid = ""
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider_arn}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_arn}:sub" = [
              "system:serviceaccount:${var.namespace}:secret-store-sa"
            ]
            "${var.oidc_provider_arn}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  path = "/gen3-service/"
}

resource "aws_iam_role_policy" "external-secrets-role-policy" {
  count = var.namespace == "default" || var.deploy_external_secrets ? 1 : 0
  name = "external-secrets-role-policy"
  role = aws_iam_role.external-secrets-role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:ListSecrets",
          "secretsmanager:GetSecretValue"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "s3-mountpoint-role" {
  count = var.namespace == "default" || var.deploy_s3_mountpoint  ? 1 : 0
  name = "${var.vpc_name}-${var.namespace}-s3-mountpoint-sa"
  description = "Role for s3 mountpoint service account for ${var.vpc_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Sid = ""
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider_arn}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_arn}:sub" = [
              "system:serviceaccount:kube-system:s3-csi-driver-sa"
            ]
            "${var.oidc_provider_arn}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  path = "/gen3-service/"
}

resource "aws_iam_role_policy" "s3-mountpoint-role-policy" {
  count = var.namespace == "default" || var.deploy_s3_mountpoint ? 1 : 0
  name = "s3-mountpoint-role-policy"
  role = aws_iam_role.s3-mountpoint-role[0].id

  policy = jsonencode({
    
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:DeleteObject"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "grafana-role" {
  count = var.namespace == "default" && var.deploy_grafana  ? 1 : 0
  name = "${var.vpc_name}-observability-role"
  description = "Role for grafana service account for ${var.vpc_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Sid = ""
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider_arn}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_arn}:sub" = [
              "system:serviceaccount:monitoring:observability"
            ]
            "${var.oidc_provider_arn}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  path = "/gen3-service/"
}

resource "aws_iam_role_policy" "grafana-role-policy" {
  count = var.namespace == "default" && var.deploy_grafana  ? 1 : 0
  name = "grafana-role-policy"
  role = aws_iam_role.grafana-role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObjectVersion",
          "s3:GetObjectVersion",
          "s3:PutObjectAcl",
          "s3:GetObjectAcl",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucketVersions"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${var.vpc_name}-observability-bucket",
          "arn:aws:s3:::${var.vpc_name}-observability-bucket/*"
        ]
      },
    ]
  })
}

# TODO Add ssjdispatcher
