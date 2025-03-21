provider "aws" {}

provider "aws" {
  alias = "csoc"
}

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
    }    
  }
}