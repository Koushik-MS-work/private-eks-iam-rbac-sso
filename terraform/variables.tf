variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name, used in tags/naming"
  type        = string
  default     = "assignment"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "private-eks-demo"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.34"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.42.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (nodes + private EKS ENIs live here)"
  type        = list(string)
  default     = ["10.42.0.0/20", "10.42.16.0/20", "10.42.32.0/20"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (NAT gateways only, no worker nodes)"
  type        = list(string)
  default     = ["10.42.48.0/24", "10.42.49.0/24", "10.42.50.0/24"]
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ (cheaper, less resilient - fine for an assignment/demo)"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = <<-EOT
    Whether the EKS API server also gets a public endpoint.
    false  = fully private cluster (task requirement #1). You must apply Terraform
             and run kubectl from something inside the VPC (bastion / VPN / Cloud9 / CodeBuild).
    true   = private + public, but public access is locked down to
             `cluster_endpoint_public_access_cidrs` (e.g. your office/home IP or a VPN egress IP),
             which makes day-to-day demoing far easier while still keeping the endpoint non-public-by-default.
  EOT
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public endpoint, only relevant if cluster_endpoint_public_access = true"
  type        = list(string)
  default     = [] # e.g. ["203.0.113.10/32"]
}

variable "node_instance_types" {
  description = "Instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

# --- Second-user / SSO access ---------------------------------------------

variable "second_user_iam_arn" {
  description = <<-EOT
    IAM principal (IAM Identity Center permission-set role, or an IAM role/user ARN)
    that should be granted scoped access to the cluster as the "other user" in the task.
    For AWS SSO this is normally the auto-created role, e.g.:
    arn:aws:iam::<account_id>:role/aws-reserved/sso.amazonaws.com/ap-south-1/AWSReservedSSO_EKSDeveloper_xxxxxxxxxxxxxxxx
  EOT
  type        = string
  default     = ""
}

variable "second_user_identity_store_username" {
  description = "Username of the second user as it exists in IAM Identity Center (leave blank to skip SSO wiring on first apply)"
  type        = string
  default     = ""
}

variable "second_user_namespace" {
  description = "Namespace the second user is scoped to via Kubernetes RBAC"
  type        = string
  default     = "dev"
}

variable "readonly_viewer_iam_arn" {
  description = "Optional: a second IAM principal ARN to grant read-only access to the staging namespace, to demonstrate the pattern generalizes"
  type        = string
  default     = ""
}

variable "namespaces" {
  description = "Application namespaces to create with per-namespace RBAC"
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}
