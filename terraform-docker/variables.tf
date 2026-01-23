variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_name" {
  type    = string
  default = "csoc-demo-test" # Modify as needed
}


variable state_bucket {
  type    = string
  default = "my-gen3-state-bucket" # Modify as needed
}