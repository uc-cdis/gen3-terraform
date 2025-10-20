echo "Running terraform plan"
terraform init
terraform plan  -var-file=/workspace/gen3-terraform/terraform.tfvars
