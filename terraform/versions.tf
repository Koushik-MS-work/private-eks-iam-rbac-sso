terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Recommended: use a remote backend (S3 + DynamoDB lock table) instead of local state.
  # Uncomment and fill in once the backend resources exist, then run `terraform init -migrate-state`.
  #
  # backend "s3" {
  #   bucket         = "koushik-tfstate-eks-assignment"
  #   key            = "eks-private-cluster/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "eks-private-cluster-assignment"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "koushik"
    }
  }
}

# Used to talk to the cluster right after creation (e.g. to apply RBAC via the
# kubernetes provider). Because the cluster is private, this only works from
# something that already has network access to the private API endpoint
# (VPN, bastion, Cloud9 in the VPC, CodeBuild in the VPC, etc.) -- see docs/README.md.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.aws_region
    ]
  }
}
