module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags so the AWS Load Balancer Controller / EKS can auto-discover subnets
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# VPC interface endpoints so a fully-private cluster (no public API endpoint) can still
# pull images from ECR, write logs, and talk to STS/SSM without going through a NAT/internet path.
# Without these, a truly private cluster with restrictive egress can fail to pull images or
# use IRSA/SSM. This is one of the "pros" of full endpoint isolation discussed in the options doc.
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.8"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
    }
    ecr_api = {
      service             = "ecr.api"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }
    ecr_dkr = {
      service             = "ecr.dkr"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }
    ec2 = {
      service             = "ec2"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }
    sts = {
      service             = "sts"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }
    logs = {
      service             = "logs"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.cluster_name}-vpce-sg"
  description = "Allow HTTPS from inside the VPC to interface endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
