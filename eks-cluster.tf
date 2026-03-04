
# 2. EKS Cluster Module

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name = "${var.cluster_name}-${var.environment}"

  # AUTOMATIC VERSIONING
  # Uses the result from the external script at the data.tf 
  
  # cluster_version = data.external.latest_k8s_version.result.version
  cluster_version = var.cluster_version
  

  # Networking
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Networking & Access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Automatically grants Admin permissions to the user running Terraform.
  enable_cluster_creator_admin_permissions = true

  # Enable IAM Roles for Service Accounts (IRSA)
  enable_irsa = true

  # Security & Compliance
  create_kms_key = true # Added: Encrypts secrets
  cluster_encryption_config = {
    resources = ["secrets"]
  }
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"] # Added: Audit logs

  # Managed Add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_NETWORK_POLICY = "true" # Added: Enables Network Controller
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }


  # Managed Node Groups

  eks_managed_node_groups = {
    # Node Group 1: Core System workloads (On-Demand, Highly Available)
    core_nodes = {
      name         = "core-node-group"
      min_size     = 1
      max_size     = 1
      desired_size = 1

      capacity_type  = "ON_DEMAND"
      instance_types = ["t3.medium", "t3.large"]

      labels = {
        role            = "core"
        "capacity-type" = "on-demand"
      }
    }

    # Node Group 2: Application workloads (Spot Instances to save cost)
    spot_nodes = {
      name         = "apps-spot-node-group"
      min_size     = 1
      max_size     = 1
      desired_size = 1

      capacity_type  = "SPOT"
      instance_types = ["t3.medium", "t3.large", "m5.large"]

      labels = {
        role            = "apps"
        "capacity-type" = "spot"
      }
    }
  }
}

# IAM Role for the EBS CSI Driver (Required for persistent volumes)
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}