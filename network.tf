

# 1. VPC Module

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]

  # PRODUCTION GRADE: Multi-AZ NAT Gateways for High Availability
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  enable_vpn_gateway     = false

  # Tags required for internal load balancers
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  # Tags required for public load balancers
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
}