# variables.tf

# Environment variable to distinguish between Dev, Staging, and Prod.
variable "environment" {
  description = "Deployment environment in this code used 'learning' as environment"
  type        = string
  default     = "learning"
}


# AWS Region
#    The region where your cluster and resources will be deployed.
#    Default is "us-east-1" (N. Virginia). Change this if you are in Europe/Asia.
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

# Cluster Name
#    This name will appear in the AWS Console and your kubeconfig file.
variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
  default     = "eks-cluster"
}

# VPC Network Range
#    The CIDR block for the Virtual Private Cloud.
#    "10.0.0.0/16" provides 65,536 IP addresses, plenty for a large cluster.
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}


# Resource Versions (Controlled via learning.tfvars)

variable "cluster_version" {
  description = "Kubernetes Version, default is latest stable version from the external data source"
  type        = string
}

variable "alb_controller_version" {
  description = "Helm chart version for AWS Load Balancer Controller"
  type        = string
}

variable "cluster_autoscaler_version" {
  description = "Helm chart version for Cluster Autoscaler"
  type        = string
}

variable "metrics_server_version" {
  description = "Helm chart version for Metrics Server"
  type        = string
}