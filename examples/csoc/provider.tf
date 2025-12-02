terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.8.0"
    }
  }
}

