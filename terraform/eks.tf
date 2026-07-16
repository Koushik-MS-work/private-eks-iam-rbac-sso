module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # nodes + control-plane ENIs only ever land in private subnets

  # --- Task requirement 1: private cluster -------------------------------
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # --- Task requirements 2/3: IAM + RBAC access management ---------------
  # Modern EKS access management (replaces the aws-auth ConfigMap). Cluster creator
  # is automatically an admin; additional principals are granted via aws_eks_access_entry below.
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      capacity_type  = "ON_DEMAND"
      subnet_ids     = module.vpc.private_subnets
    }
  }

  # Encrypt Kubernetes secrets at rest with a dedicated KMS key
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  tags = {
    "task" = "private-eks-assignment"
  }
}

# KMS key used for the cluster_encryption_config above is created automatically by the
# module when cluster_encryption_config is set without an explicit provider_key_arn;
# see module outputs for the ARN if you need to reference it (e.g. in the options doc / IAM policies).
