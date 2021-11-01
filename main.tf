provider "aws" {
  region = "eu-central-1"
}

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "public_key_location" {}


resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name      = "${var.env_prefix}-vpc"
    ManagedBy = "Terraform"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id            = aws_vpc.myapp-vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name      = "${var.env_prefix}-subnet-1"
    ManagedBy = "Terraform"
  }
}

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id

  tags = {
    Name      = "${var.env_prefix}-igw"
    ManagedBy = "Terraform"
  }
}

# enhance the default route table of a created vpc
# instead of creating two resources: new route table + an association
resource "aws_default_route_table" "myapp-main-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }

  tags = {
    Name      = "${var.env_prefix}-main-rtb"
    ManagedBy = "Terraform"
  }
}

# resource "aws_route_table" "myapp-route-table" {
#   vpc_id = aws_vpc.myapp-vpc.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.myapp-igw.id
#   }


#   tags = {
#     Name      = "${var.env_prefix}-rtb"
#     ManagedBy = "Terraform"
#   }
# }

# resource "aws_route_table_association" "myapp-a-rtb-subnet-1" {
# 	subnet_id = aws_subnet.myapp-subnet-1.id
# 	route_table_id = aws_route_table.myapp-route-table.id
# }

resource "aws_security_group" "myapp-sg" {
  name   = "myapp-sg"
  vpc_id = aws_vpc.myapp-vpc.id

  # firewall rules of this sg for incoming(ingress)/outgoing(egress) traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // allow any traffic to leave the instance
  egress {
    from_port       = 0 // any
    to_port         = 0
    protocol        = "-1"          // any
    cidr_blocks     = ["0.0.0.0/0"] // any
    prefix_list_ids = []
  }

  tags = {
    Name      = "${var.env_prefix}-sg"
    ManagedBy = "Terraform"
  }
}

# enhance the default security group of the vpc
resource "aws_default_security_group" "myapp-default-sg" {
  vpc_id = aws_vpc.myapp-vpc.id

  # firewall rules of this sg for incoming(ingress)/outgoing(egress) traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // allow any traffic to leave the instance
  egress {
    from_port       = 0 // any
    to_port         = 0
    protocol        = "-1"          // any
    cidr_blocks     = ["0.0.0.0/0"] // any
    prefix_list_ids = []
  }

  tags = {
    Name      = "${var.env_prefix}-default-sg"
    ManagedBy = "Terraform"
  }
}

data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

output "ec2_public_ip" {
  value = aws_instance.myapp-server.public_ip
}

resource "aws_key_pair" "ssh-key" {
	key_name = "terraform-server-key"
	# aws uses pk from ~/.ssh to create the private-public key pair
	# public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsb8k2h0wAfPu3ad8mFwWFzO/MwQCvvSmQ/g7Y4O142B2hDktm9ctZbW2ip9yDmXNX06tL1xZMXMH6dDVuNnaJGZNJcJp0A7vtMxlaoYCJ6HNHurFpa7YEDx6ckUO617oOBE5ilJrEvu7niu/N+NKyVAJ/MM+O/Y+iIAfu2aWs1f1wwQFyWrlOwhsDnE/e+dy6R6XmfvAyOuDih5ImXW4Dy4iy4M0zwFpxJFH/NCmnlWW+VbsK04JXHmHvHbovCAl/khDmb+wyIptCaSNLjZjn60FyGyCo7UcylsUGWaPpk7J0n05atcvZgFkwFt2wL1teATXP+6x1oavSnZgUhkBp ioan-leonard.filip@haufe.com"
	# or reference the file location
	public_key = file(var.public_key_location)
}

resource "aws_instance" "myapp-server" {
  # this is enough ..
  ami           = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type

  # but we want to make sure this instance ends up in our created VPC
  # and gets our defined security group
  subnet_id              = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_default_security_group.myapp-default-sg.id]
  availability_zone      = var.avail_zone

  # enable outside access into instance
  associate_public_ip_address = true

  # associate a .pem key with the instance; name defined in aws
  # key_name = "terraform-ssh-key-pair"
  key_name = aws_key_pair.ssh-key.key_name

	# entrypoint script executed on the instance, when initialised
	# provide it multiline
	# update packages, install docker, start docker, add ec2 user
	# to docker group (to execute docker commands without sudo)
	# user_data = <<EOF
	# 							#!/bin/bash
	# 							sudo yum update -y && sudo yum install -y docker
	# 							sudo systemctl start docker
	# 							sudo usermod -aG docker ec2-user
	# 							docker run -p 8080:80 nginx
	# 						EOF

	# or reference a file..
	user_data = file("entry-script.sh")


  tags = {
    Name      = "${var.env_prefix}-server" 
    ManagedBy = "Terraform"
  }
}