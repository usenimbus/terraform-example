terraform {
  required_providers {
    nimbus = {
      source = "usenimbus/nimbus"
    }
  }
}

variable "nimbusAuthToken" {
  description = "Nimbus Auth Token"
}

provider "nimbus" {
  auth_token = var.nimbusAuthToken
}

variable "region" {
  description = "region"
  default     = "us-west-2"
  validation {
    condition = contains([
      "ap-southeast-1",
      "us-east-1",
      "us-west-2"
    ], var.region)
    error_message = "invalid region"
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

variable "workspace_name" {
  description = "Name your workspace"
  default     = ""
}

variable "template_id" {
  description = "Nimbus Template Id"
  default     = ""
}

provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "tag:ubuntu-version"
    values = ["focal"]
  }
  owners = ["211075537450"] # Canonical
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_default_subnet" "default" {
  availability_zone = "us-west-2a"

  tags = {
    Name = "Default subnet for us-west-2a"
  }
}

locals {
  vpc       = aws_default_vpc.default.id
  # az        = keys(local.region_vpc_az_subnet_map[var.region][local.vpc])[0]
  subnet_id = aws_default_subnet.default.id
  ami       = data.aws_ami.ubuntu.id
  hostname  = "${var.workspace_name}.dev.usenimbus.com"
}

resource "aws_security_group" "www" {
  name   = var.workspace_name
  vpc_id = local.vpc

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name      = var.workspace_name
    ManagedBy = "Nimbus"
  }
}

resource "aws_instance" "www" {
  depends_on = [
    aws_security_group.www
  ]

  ami                         = local.ami
  instance_type               = var.instance_type
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.www.id]
  subnet_id                   = local.subnet_id

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.storage
    delete_on_termination = true
    encrypted             = true
    throughput            = 250

    tags = {
      Name      = var.workspace_name
      ManagedBy = "Nimbus"
    }
  }

  tags = {
    Name      = var.workspace_name
    ManagedBy = "Nimbus"
  }
}

data "nimbus_template" "www" {
  id = var.template_id
}

resource "nimbus_workspace" "www_dev" {
  depends_on = [
    aws_instance.www
  ]

  name        = var.workspace_name
  template_id = data.nimbus_template.www.id
  region      = var.region

  instance_id       = aws_instance.www.id
  security_group_id = aws_security_group.www.id

  schedule {
    schedule_enabled              = true
    inactivity_timeout_in_minutes = 60
    schedule_groups {
      days {
        day               = "Thursday"
        start_time_hour   = 3
        start_time_minute = 0
        end_time_hour     = 4
        end_time_minute   = 0
      }
      days {
        day               = "Friday"
        start_time_hour   = 3
        start_time_minute = 0
        end_time_hour     = 4
        end_time_minute   = 0
      }
      days {
        day               = "Monday"
        start_time_hour   = 1
        start_time_minute = 0
        end_time_hour     = 8
        end_time_minute   = 0
      }
    }
  }
}
