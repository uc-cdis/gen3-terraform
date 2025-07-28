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

data "aws_eks_cluster" "selected" {
  name = var.vpc_name
}

provider "kubernetes" {
  host                   = module.eks.0.cluster_endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.selected.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", var.vpc_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.0.cluster_endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.selected.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", var.vpc_name]
    }
  }
}