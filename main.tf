terraform {
    required_providers{
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region = var.aws_region
}

module "vpc" {
    source = "./modules/vpc"
}

module "nat_gateway" {
    source = "./modules/nat-gateway"
    public_subnet_id = module.vpc.public_subnet_id
}

# Route tro Private Subnet ra NAT Gateway
resource "aws_route" "private_nat_route" {
    route_table_id = module.vpc.private_route_table_id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = module.nat_gateway.nat_gw_id
}

module "security_groups" {
    source = "./modules/security-groups"
    vpc_id = module.vpc.vpc_id
    ip = var.ip
}

module "ec2" {
    source = "./modules/ec2"
    public_subnet_id = module.vpc.public_subnet_id
    private_subnet_id = module.vpc.private_subnet_id
    public_sg_id = module.security_groups.public_sg_id
    private_sg_id = module.security_groups.private_sg_id
}
