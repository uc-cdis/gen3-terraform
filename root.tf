### \---------------------------------------------------------------------------------------------------------------------

### TERRAGRUNT ROOT CONFIGURATION

### \---------------------------------------------------------------------------------------------------------------------

### Automatically configure the remote state backend (AWS S3 example)

# TODO:
#remote\_state {
#backend = "s3"
#generate = {
#path = "backend.tf"
#if\_exists = "overwrite\_terragrunt"
#}
#config = {
#bucket = "my-company-terragrunt-state-bucket"
#key = "${path\_relative\_to\_include()}/terraform.tfstate"
#region = "us-east-1"
#encrypt = true
#dynamodb\_table = "my-company-lock-table"
#}
#

### Automatically generate the AWS provider block in child module

generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
provider "aws" {
	region = "us-east-1"
	default_tags {
	  tags = {
#	  	Environment = "production"
#	  	ManagedBy = "Terragrunt"
#	  }
#	}
#}
EOF
}
