# Filter out local zones, which are not supported by EKS managed node groups
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Select the first 3 availability zones in the region
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

# -------------------------------------------------------------------------
# 1. VPC Module
# -------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true # Keep true for Dev to save costs
  enable_vpn_gateway = false

  # Tags required for internal load balancers
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  # Tags required for public load balancers
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
}

# -------------------------------------------------------------------------
# 2. EKS Cluster Module
# -------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  # Networking
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Public endpoint allows you to run kubectl from your local machine
  cluster_endpoint_public_access = true

  # -----------------------------------------------------------------------
  # ACCESS CONTROL
  # -----------------------------------------------------------------------
  # This automatically grants Admin permissions to the user running Terraform.
  # No extra IAM configuration is needed.
  enable_cluster_creator_admin_permissions = true

  # -----------------------------------------------------------------------
  # Managed Node Groups (Spot Instances)
  # -----------------------------------------------------------------------
  eks_managed_node_groups = {
    spot_nodes = {
      name = "spot-node-group"

      min_size     = 1
      max_size     = 1
      desired_size = 1

      # TELL AWS TO USE SPOT INSTANCES
      capacity_type = "SPOT"

      # DIVERSIFY INSTANCE TYPES for stability
      instance_types = ["t3.medium", "t3.large", "m5.large"]

      labels = {
        "capacity-type" = "spot"
      }
    }
  }

  # Enable IAM Roles for Service Accounts (IRSA)
  enable_irsa = true

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}