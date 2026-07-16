resource "kubernetes_namespace" "app_namespaces" {
  for_each = toset(var.namespaces)

  metadata {
    name = each.value
    labels = {
      "managed-by" = "terraform"
    }
  }

  depends_on = [module.eks]
}

# RBAC Role/RoleBinding objects are applied separately via kubectl/kustomize from
# ../k8s-rbac (see docs/README.md) rather than the kubernetes provider, so that:
#   1) they can be demoed / diffed independently of a `terraform apply`,
#   2) they still work if you ever swap the control-plane access method,
#   3) a non-Terraform reviewer can read plain YAML without needing HCL context.
# If you'd rather keep everything in one `terraform apply`, the same manifests can be
# ported to kubernetes_role / kubernetes_role_binding resources with minimal changes.
