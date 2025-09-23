terraform {
  backend "s3" {
    # The bucket to store the Terraform state file in.
    bucket = "cdis-terraform-state.account-433568766270.gen3" # Update to represent your environment
    # The location of the Terraform state file within the bucket.
    key = "jq-csoc-gen3-commons/terraform.tfstate" # Update to represent your environment    
    encrypt = "true"
    # The region where the S3 bucket is located.
    region = "us-east-1"
  }
}