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
      version = "~> 2.8.0"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.0.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.0.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.0.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.0.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.0.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.0.cluster_name]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.0.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.0.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.0.cluster_name]
  }
}

provider "aws" {}

provider "aws" {
  alias = "csoc"
}
