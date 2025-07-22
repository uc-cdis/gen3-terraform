# Inject credentials via the AWS_PROFILE environment variable and shared credentials file
# and/or EC2 metadata service
terraform {
  backend "s3" {
    encrypt = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.17.0"
    }
  }
}


ephemeral "aws_eks_cluster_auth" "eks_cluster" {
  name       = var.vpc_name
}

provider "kubernetes" {
  host                   = module.eks.0.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.0.cluster_certificate_authority_data)
  token                  = ephemeral.aws_eks_cluster_auth.eks_cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.0.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.0.cluster_certificate_authority_data)
    token                  = ephemeral.aws_eks_cluster_auth.eks_cluster.token
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.0.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.0.cluster_certificate_authority_data)
  load_config_file       = false
  token                  = ephemeral.aws_eks_cluster_auth.eks_cluster.token
}

provider "aws" {}

provider "aws" {
  alias = "csoc"
}