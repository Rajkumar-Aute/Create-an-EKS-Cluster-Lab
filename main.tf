# main.tf

# -------------------------------------------------------------------------
# Data Sources
# -------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# -------------------------------------------------------------------------
# DYNAMIC VERSION CHECK
# -------------------------------------------------------------------------
# This script asks AWS: "What are all the valid cluster versions you support?"
# It then sorts them and picks the highest one.
# This ensures that if you run this in 2028, it will pick v1.35 (or whatever is new).
data "external" "latest_k8s_version" {
  program = ["bash", "-c", <<EOT
    ver=$(aws eks describe-addon-versions --addon-name vpc-cni \
      --query 'addons[].addonVersions[].compatibilities[].clusterVersion' \
      --output text | tr '\t' '\n' | sort -V | tail -n 1)
    echo "{\"version\": \"$ver\"}"
  EOT
  ]
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
  # -----------------------------------------------------------------------
  # AUTOMATIC VERSIONING
  # -----------------------------------------------------------------------
  # Uses the result from the external script at the top of the file
  cluster_version = data.external.latest_k8s_version.result.version

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