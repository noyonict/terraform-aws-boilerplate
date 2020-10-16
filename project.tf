terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "my-access-key"
  secret_key = "my-secret-key"
}



# 1. Create VPC
# Create a VPC
resource "aws_vpc" "first_vpc" {
  cidr_block = "10.0.0.0/16"
}


# 2. Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.first_vpc.id

  tags = {
    Name = "prod"
  }
}

# 3. Create Custom Route Table
resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.first_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.ip
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_internet_gateway.gw.ip
  }

  tags = {
    Name = "prod"
  }
}

# 4. Crate a Subnet
resource "aws_subnet" "first_subnet" {
  vpc_id     = aws_vpc.first_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

# 5. Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.first_subnet.id
  route_table_id = aws_route_table.prod_route_table.id
}

# 6. Create Security Group to all port 22, 80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_trafic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.first_vpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "prod" {
  subnet_id       = aws_subnet.first_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
  depends_on = ["aws_internet_gateway.gw"]

#   attachment {
#     instance     = aws_instance.test.id
#     device_index = 1
#   }
}

# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.prod.id
  associate_with_private_ip = "10.0.1.50"
}

output "server_public_ip" {
    value = aws_eip.one.public_ip
}



# 9. Create Ubuntu server and install/ebable apache2
resource "aws_instance" "prod-server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "pre-key-pair"

  network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.prod.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server Deployed via Terraform > /var/www/html/index.html'
              EOF
    # user_data = <<-EOF
    #             #! /bin/bash
    #             sudo apt-get update -y
    #             sudo apt-get install -y apache2
    #             sudo systemctl start apache2
    #             sudo systemctl enable apache2
    #             echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
    #             EOF

  tags = {
    Name = "prod"
  }
}

output "server_private_ip" {
    value = aws_instance.prod-server.private_ip
}

output "server_id" {
    value = aws_instance.prod-server.private_id
}
