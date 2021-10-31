provider "aws" {
	region = "eu-central-1"
}

resource "aws_vpc" "dev_vpc" {
	cidr_block = "10.0.0.0/16"

	tags = {
		Course = "Nana"
		ManagedBy = "Terraform"
	}
}