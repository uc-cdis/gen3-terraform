# Terraform for Cloud Automation

This repository contains Terraform configuration files to set up cloud infrastructure for the Cloud Automation project. The Terraform files are located in the `tf_files` directory. This README will guide you through the process of running Terraform to create, modify, and destroy cloud resources.

## Prerequisites

1. Install Terraform: To work with Terraform, you need to have it installed on your local machine. Visit the [official Terraform download page](https://www.terraform.io/downloads.html) and follow the instructions for your operating system.

2. Configure cloud provider credentials: Terraform uses provider-specific credentials to authenticate and interact with the cloud provider. Make sure you have the necessary credentials configured. The `tf_files` directory contains multiple subdirectories for different cloud providers (e.g., `aws`, `gcp`). Check the provider-specific documentation for instructions on configuring credentials.

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/uc-cdis/gen3-terraform.git
   ```
2. Navigate to the `tf_files` directory:
   ```bash
   cd gen3-terraform/tf_files
   ```
3. Choose the appropriate subdirectory for your cloud provider (e.g., `aws`, `gcp`). In this example, we will use the `aws` directory:
   ```bash
   cd aws
   ```
4. Initialize Terraform:
   ```bash
   terraform init
   ```
   This command downloads the necessary provider plugins and sets up the backend for storing the Terraform state.

5. Create a new Terraform workspace (optional):
   ```bash
   terraform workspace new my_workspace
   ```
   This step is optional but recommended if you plan to manage multiple environments or if you're collaborating with others.

6. Review the Terraform plan:
   ```bash
   terraform plan
   ```
   This command shows a summary of the changes that Terraform will apply to your cloud resources.

7. Apply the Terraform configuration:
   ```bash
   terraform apply
   ```
   This command prompts you to confirm that you want to apply the changes and then proceeds to create, update, or delete cloud resources as needed.

8. Verify the infrastructure:

Check your cloud provider's management console or CLI to verify that the resources have been created or modified as expected.

## Cleanup

1. Destroy the infrastructure:
   ```bash
   terraform destroy
   ```
   This command removes all resources created by Terraform.

2. Delete the Terraform workspace (if created earlier):
   ```bash
   terraform workspace select default
   terraform workspace delete my_workspace
   ```
3. Remove the `.terraform` directory and any generated `.tfstate` files.

## Troubleshooting

If you encounter any issues while working with Terraform, refer to the [official Terraform documentation](https://www.terraform.io/docs/index.html) and the cloud provider's documentation for help.

## Contributing

Contributions to improve or extend the Terraform configurations in this repository are welcome! Please submit a pull request or open an issue to discuss any changes you would like to make.

