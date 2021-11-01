provider "aws" {
  region = "eu-central-1"
}

# resource "aws_vpc" "myapp-vpc" {
#   cidr_block = var.vpc_cidr_block
#   tags = {
#     Name      = "${var.env_prefix}-vpc"
#     ManagedBy = "Terraform"
#   }
# }

# module "myapp-subnet" {
#   source = "./modules/subnet"
#   vpc_id = aws_vpc.myapp-vpc.id
#   subnet_cidr_block = var.subnet_cidr_block
#   avail_zone = var.avail_zone
#   env_prefix = var.env_prefix
#   default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
# }

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = var.vpc_cidr_block

  azs             = [var.avail_zone]
  public_subnets  = [var.subnet_cidr_block]

  tags = {
    Name      = "${var.env_prefix}-vpc"
    ManagedBy = "Terraform"
  }

  public_subnet_tags = {
    Name      = "${var.env_prefix}-subnet-1"
    ManagedBy = "Terraform"
  }
}

module "webserver" {
  source = "./modules/webserver"
  vpc_id = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnets[0]
  my_ip = var.my_ip
  public_key_location = var.public_key_location
  instance_type = var.instance_type
  avail_zone = module.vpc.azs[0]
  env_prefix = var.env_prefix
}