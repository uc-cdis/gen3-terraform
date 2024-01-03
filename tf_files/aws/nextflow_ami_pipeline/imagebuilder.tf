## Image builder component to install AWS cli using conda

locals {
  aws_imagebuilder_component_install_software = data.aws_imagebuilder_component.install_software == null ? aws_imagebuilder_component.install_software[0].name : data.aws_imagebuilder_component.install_software.name
}

# Data to get aws account id
data "aws_caller_identity" "current" {}

data "aws_imagebuilder_component" "install_software" {
  arn = "arn:aws:imagebuilder:us-east-1:${data.aws_caller_identity.current.account_id}:component/installsoftware/1.0.1/1"
}

resource "aws_imagebuilder_component" "install_software" {
  count = data.aws_imagebuilder_component.install_software.id == null ? 1 : 0
  name     = "InstallSoftware"
  platform = "Linux"
  version  = "1.0.1"

  data = yamlencode({
    name        = "InstallSoftware"
    description = "Installs bzip2, wget, Miniconda3 and awscli"
    schemaVersion = 1.0

    phases = [{
      name = "build"
      steps = [{
        name = "InstallPackages"
        action = "ExecuteBash"
        inputs = {
          commands = [
            "sudo yum install -y bzip2 wget"
          ]
        }
      },
      {  
        name = "InstallMiniconda"
        action = "ExecuteBash" 
        inputs = {
          commands = [
            "sudo su ec2-user",
            "mkdir -p /home/ec2-user",
            "export HOME=/home/ec2-user/",
            "cd $HOME",
            "# Download and install miniconda in ec2-user's home dir",
            "wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda-install.sh",
            "bash miniconda-install.sh -b -f -p /home/ec2-user/miniconda",
            "rm miniconda-install.sh"
          ]
        }
      },
      {
        name = "InstallAWSCLI"
        action = "ExecuteBash"
        inputs = {
          commands = [
            "export HOME=/home/ec2-user/",
            "/home/ec2-user/miniconda/bin/conda install -c conda-forge -y awscli"
          ]
        }  
      }]
    },
    {
      name = "validate"
      steps = [{
        name = "CheckInstalls"
        action = "ExecuteBash"
        inputs = {
          commands = [
            "which bzip2",
            "which wget",
            "which conda", 
            "/home/ec2-user/miniconda/bin/conda list | grep awscli"
          ]
        }
      }]
    },
    {
      name = "test"
      steps = [{
        name = "TestAWSCLI"
        action = "ExecuteBash"
        inputs = {
          commands = [
            "/home/ec2-user/miniconda/bin/aws --version"
          ]
        }
      }]
    }]
  })
}


## Image builder infrastructure config 
resource "aws_imagebuilder_infrastructure_configuration" "image_builder" {
  name = "nextflow-infra-config"
  instance_profile_name = aws_iam_instance_profile.image_builder.name
  security_group_ids = [data.aws_security_group.default.id]    
  subnet_id = data.aws_subnet.private.id
  terminate_instance_on_failure = true
}


## Make sure the ami produced is public

resource "aws_imagebuilder_distribution_configuration" "public_ami" {
  name = "public-ami-distribution"

  distribution {    
    ami_distribution_configuration {
      name = var.public_ami_name

      ami_tags = {
        Role = "Public Image"
      }
      
      launch_permission {
        user_groups = ["all"]
      }
    }

    region = "us-east-1"
  }
}


## Image recipe 
resource "aws_imagebuilder_image_recipe" "recipe" {
  name = var.recipe_name
  
  parent_image = var.base_image 

  version = var.recipe_version
  
  block_device_mapping {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_size           = 30
      volume_type           = "gp2"
      encrypted = false
    }
  }

  user_data_base64 = try(base64encode(var.user_data), null)

  # TODO: Do we need this? ECS optimized should come with docker
  component {
    component_arn = "arn:aws:imagebuilder:us-east-1:aws:component/docker-ce-linux/1.0.0/1"
  }

  component {
    component_arn = local.aws_imagebuilder_component_install_software
  }

  
  
}


# Image builder pipeline

resource "aws_imagebuilder_image_pipeline" "nextflow" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.image_builder.arn
  name                             = var.pipeline_name

  distribution_configuration_arn = aws_imagebuilder_distribution_configuration.public_ami.arn
  
  image_scanning_configuration {
    image_scanning_enabled = var.image_scanning_enabled
  }

}
