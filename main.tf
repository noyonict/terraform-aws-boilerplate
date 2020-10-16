terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

variable "subnet_prefix" {
    description = "CIDR block for the subnet"
    # default = ""
    # type = any/String/Integer
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "my-access-key"
  secret_key = "my-secret-key"
}

resource "aws_instance" "my-first-server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  tags = {
    Name = "terraform"
  }
}

# Create a VPC
resource "aws_vpc" "first_vpc" {
  cidr_block = var.subnet_prefix3[0]
}


resource "aws_subnet" "first_subnet" {
  vpc_id     = aws_vpc.first_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "prod-subnet"
  }
}

# Create a VPC
resource "aws_vpc" "second_vpc" {
  cidr_block = "10.1.0.0/16"
}


resource "aws_subnet" "second_subnet" {
  vpc_id     = aws_vpc.second_vpc.id
  cidr_block = "10.1.1.0/24"

  tags = {
    Name = "dev-subnet"
  }
}


