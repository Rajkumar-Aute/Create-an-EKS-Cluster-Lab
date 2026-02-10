# main.tf

# -------------------------------------------------------------------------
# Data Sources
# -------------------------------------------------------------------------
# Query AWS for available Availability Zones (AZs) in the current region.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Select the first 3 availability zones (e.g., us-east-1a, 1b, 1c)
  # This ensures high availability for our cluster.
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

# -------------------------------------------------------------------------
# 1. VPC Module
#    Creates a network optimized for EKS with public/private subnets
# -------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  # Distribute subnets across the 3 AZs we selected earlier
  azs = local.azs

  # Private Subnets: For worker nodes (secure, no direct internet access)
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]

  # Public Subnets: For Load Balancers (accessible from internet)
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]

  # NAT Gateway: Allows private nodes to download updates/images
  enable_nat_gateway = true
  single_nat_gateway = true # Set to 'false' for high availability in Prod
  enable_vpn_gateway = false

  # TAGS: Essential for the AWS Load Balancer Controller to find subnets
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
}

# -------------------------------------------------------------------------
# 2. EKS Cluster Module
#    Creates the Control Plane and manages the worker nodes
# -------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31" # Always use a recent, supported Kubernetes version

  # Networking: Connect EKS to the VPC created above
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # Worker nodes go in private subnets

  # Access: Allow kubectl access from your laptop
  cluster_endpoint_public_access = true

  # -----------------------------------------------------------------------
  # IAM Access Control (Authentication)
  # -----------------------------------------------------------------------
  
  # 1. Grant Admin permissions to the person running 'terraform apply'
  enable_cluster_creator_admin_permissions = true

  # 2. Grant Admin permissions to an additional User (if provided in variables)
  #    This uses the modern 'Access Entries' API (replacing aws-auth).
  access_entries = var.admin_user_arn != "" ? {
    additional_admin = {
      principal_arn = var.admin_user_arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  } : {}

  # -----------------------------------------------------------------------
  # Managed Node Groups (Spot Instances)
  # -----------------------------------------------------------------------
  eks_managed_node_groups = {
    spot_nodes = {
      name = "spot-node-group"

      # Autoscaling: The cluster can grow/shrink between these numbers
      min_size     = 1
      max_size     = 1
      desired_size = 1

      # COST SAVINGS: Tell AWS to use Spot Instances (up to 90% cheaper)
      capacity_type = "SPOT"

      # RELIABILITY: Provide multiple instance types.
      # If 't3.medium' is sold out, AWS will auto-try 't3.large' or 'm5.large'.
      instance_types = ["t3.medium", "t3.large", "m5.large"]

      # Labels: Useful for scheduling pods specifically on Spot nodes
      labels = {
        "capacity-type" = "spot"
      }
    }
  }

  # Enable IAM Roles for Service Accounts (IRSA) 
  # This allows pods to securely access AWS services (like S3 or DynamoDB).
  enable_irsa = true

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}