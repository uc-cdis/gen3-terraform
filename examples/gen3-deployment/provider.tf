terraform {
  required_providers {
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
  depends_on = [ module.commons ]
  name = local.vpc_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.selected.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.selected.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", "${local.vpc_name}"]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.selected.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.selected.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", "${local.vpc_name}"]
    }
  }
}
