## IAM Instance Profile for image builder

locals {
  image_builder_iam_role = data.aws_iam_role.existing_image_builder == null ? aws_iam_role.image_builder[count.index].name : data.aws_iam_role.existing_image_builder.name
}

# Attempt to fetch the existing IAM role
data "aws_iam_role" "existing_image_builder" {
  name = "EC2InstanceProfileForImageBuilder-nextflow"
  # This will fail if the role does not exist
}

# Conditionally create the IAM role if it does not already exist
resource "aws_iam_role" "image_builder" {
  count              = data.aws_iam_role.existing_image_builder.id == null ? 1 : 0
  name               = "EC2InstanceProfileForImageBuilder-nextflow"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json 
}


data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]    
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "amazon_ssm" {
  role       = local.image_builder_iam_role
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "image_builder" {
  role       = local.image_builder_iam_role
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

resource "aws_iam_role_policy_attachment" "image_builder_ecr" {
  role       = local.image_builder_iam_role
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
}

resource "aws_iam_instance_profile" "image_builder" {
  name = "image-builder-profile"
  role = local.image_builder_iam_role
}
