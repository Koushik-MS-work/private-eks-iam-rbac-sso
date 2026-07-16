output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Private EKS API endpoint (only reachable from inside the VPC / peered network)"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "second_user_resolved_arn" {
  description = "IAM principal that was actually mapped into the cluster via the EKS access entry"
  value       = local.second_user_resolved_arn
}

output "admin_kubeconfig_command" {
  description = "Run this (from inside the VPC, e.g. bastion/SSM/VPN) as the cluster-creator admin"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --alias ${module.eks.cluster_name}-admin"
}

output "second_user_kubeconfig_command" {
  description = "What the second user runs after `aws sso login`, using an AWS CLI profile pointed at the EKSDeveloper permission set"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --profile eks-developer-sso --alias ${module.eks.cluster_name}-dev"
}
