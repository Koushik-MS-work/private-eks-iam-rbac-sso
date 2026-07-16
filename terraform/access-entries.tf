# --- Task requirements 2 & 3: grant access + IAM <-> Kubernetes RBAC mapping ---
#
# EKS Access Entries are the modern replacement for hand-editing the aws-auth ConfigMap.
# An access entry maps an IAM principal to one or more Kubernetes usernames/groups.
# We deliberately do NOT attach a broad AWS-managed access policy (e.g. AmazonEKSAdminPolicy)
# to the second user -- instead we map them only to a Kubernetes group, and Kubernetes
# RBAC (k8s-rbac/*.yaml) grants that group namespace-scoped permissions only. This keeps
# the "who can authenticate" (IAM) and "what they can do" (RBAC) concerns separate, which
# is the cleanest way to satisfy "different namespaces, different access".

locals {
  # Falls back to the dynamically-discovered SSO role if second_user_iam_arn wasn't set explicitly.
  second_user_resolved_arn = var.second_user_iam_arn != "" ? var.second_user_iam_arn : try(
    tolist(data.aws_iam_roles.sso_eks_developer_role.arns)[0],
    ""
  )
}

resource "aws_eks_access_entry" "second_user" {
  count = local.second_user_resolved_arn == "" ? 0 : 1

  cluster_name  = module.eks.cluster_name
  principal_arn = local.second_user_resolved_arn
  type          = "STANDARD"

  # No `username` override needed for a role-based principal; EKS derives one from the ARN.
  # This is what shows up as `kubectl get rolebinding -o yaml` subjects and in `kubectl auth can-i`.
  kubernetes_groups = ["${var.second_user_namespace}-namespace-users"]

  tags = {
    purpose = "second-user-namespace-scoped-access"
  }
}

# Example: a second namespace-scoped principal with read-only access to staging, to show
# the pattern generalizes (grant a group per namespace, per access level).
resource "aws_eks_access_entry" "example_readonly" {
  count = var.readonly_viewer_iam_arn == "" ? 0 : 1

  cluster_name      = module.eks.cluster_name
  principal_arn     = var.readonly_viewer_iam_arn
  type              = "STANDARD"
  kubernetes_groups = ["staging-namespace-viewers"]
}
