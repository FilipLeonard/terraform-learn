resource "aws_security_group" "myapp-sg" {
  name   = "myapp-sg"
  vpc_id = var.vpc_id

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
  vpc_id = var.vpc_id

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

resource "aws_key_pair" "ssh-key" {
  key_name = "terraform-server-key"
  # aws uses pk from ~/.ssh to create the private-public key pair
  # public_key = "ssh-rsa AAAAB3Nz..."
  # or reference the file location
  public_key = file(var.public_key_location)
}

resource "aws_instance" "myapp-server" {
  # this is enough ..
  ami           = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type

  # but we want to make sure this instance ends up in our created VPC
  # and gets our defined security group
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
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
  # 							...
  # 						EOF

  # or reference a file..
  user_data = file("./entry-script.sh")


  tags = {
    Name      = "${var.env_prefix}-server"
    ManagedBy = "Terraform"
  }
}