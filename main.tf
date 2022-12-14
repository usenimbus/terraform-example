terraform {
  backend "s3" {
    bucket = "nimbus-terraform-workspaces"
    region = "us-west-2"
  }

  required_providers {
    nimbus = {
      source = "usenimbus/nimbus"
    }
  }
}

variable "region" {
  description = "region"
  validation {
    condition = contains([
      "us-west-2"
    ], var.region)
    error_message = "region not supported"
  }
}

variable "instance_type" {
  description = "instance type"
  default     = "t3.large"
  validation {
    condition = contains([
      "t3.medium",
      "t3.large",
      "t3.xlarge",
      "t3.2xlarge",
    ], var.instance_type)
    error_message = "invalid instance type"
  }
}

variable "storage" {
  description = ""
  default     = 50
}

provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["099720109477"] # Canonical
}


locals {
  vpcs    = { "us-west-2" : "vpc-03add4cfea117e679" }
  subnets = { "us-west-2" : "subnet-0b3238ac3635afc2d" }
  vpc     = local.vpcs[var.region]
  subnet  = local.subnets[var.region]
  ami     = data.aws_ami.ubuntu.id
}

resource "aws_instance" "nimbus" {

  user_data = <<-EOF
    #!/usr/bin/env bash
    
    sudo mkdir /home/nimbus-user
    sudo useradd -m -d /home/nimbus-user nimbus-user
    sudo adduser nimbus-user sudo
    sudo chown nimbus-user:nimbus-user /home/nimbus-user
    
    sudo echo "nimbus-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/90-nimbus-users
    sudo echo "nimbus-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/90-nimbus-users
    sudo echo "nimbus-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/90-nimbus-users
    sudo echo "nimbus-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/90-nimbus-users
    
  EOF

  ami                         = local.ami
  instance_type               = var.instance_type
  associate_public_ip_address = true
  subnet_id                   = local.subnet
  vpc_security_group_ids      = [aws_security_group.www.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.storage
    delete_on_termination = true
    encrypted             = true
    throughput            = 250

    tags = {
      ManagedBy = "Nimbus"
    }
  }

  tags = {
    ManagedBy = "Nimbus"
  }
}

resource "nimbus_workspace_metadata" "workspace" {
  name = "workspace" # `workspace` is a reserved name for top level workspace metadata

  backend {
    type        = "aws_ec2"
    region      = var.region
    instance_id = resource.aws_instance.nimbus
  }

  item {
    key   = "instance_status"
    value = "stopped"
  }

  item {
    key   = "additional security group id"
    value = "sg-abcdefg"
  }


}

resource "nimbus_workspace_metadata" "arbitrary_metadata" {
  item {
    key   = "instance_status"
    value = "stopped"
  }

  item {
    key       = "security_group_id"
    value     = "sg-abcdefg"
    sensitive = true
  }
}
