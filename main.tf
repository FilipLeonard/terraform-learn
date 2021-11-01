provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name      = "${var.env_prefix}-vpc"
    ManagedBy = "Terraform"
  }
}

module "myapp-subnet" {
  source = "./modules/subnet"
  vpc_id = aws_vpc.myapp-vpc.id
  subnet_cidr_block = var.subnet_cidr_block
  avail_zone = var.avail_zone
  env_prefix = var.env_prefix
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
}

module "webserver" {
  source = "./modules/webserver"
  vpc_id = aws_vpc.myapp-vpc.id
  subnet_id = module.myapp-subnet.subnet.id
  my_ip = var.my_ip
  public_key_location = var.public_key_location
  instance_type = var.instance_type
  avail_zone = var.avail_zone
  env_prefix = var.env_prefix
}