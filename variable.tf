# variables.tf

# 1. AWS Region
#    The region where your cluster and resources will be deployed.
#    Default is "us-east-1" (N. Virginia). Change this if you are in Europe/Asia.
variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

# 2. Cluster Name
#    This name will appear in the AWS Console and your kubeconfig file.
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "EKS cluster"
}

# 3. VPC Network Range
#    The CIDR block for the Virtual Private Cloud.
#    "10.0.0.0/16" provides 65,536 IP addresses, plenty for a large cluster.
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# 4. Admin User ARN (Optional)
#    If you want to give a specific colleague or IAM user Admin access immediately,
#    paste their ARN here (e.g., "arn:aws:iam::123456789012:user/jdoe").
#    Leave it empty ("") if only the person running Terraform needs access.
variable "admin_user_arn" {
  description = "ARN of an additional IAM user to grant admin access"
  type        = string
  default     = "" 
}