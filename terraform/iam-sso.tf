# --- Task requirement 4: access via AWS IAM Identity Center (AWS SSO) ------
#
# Prerequisite: IAM Identity Center must already be *enabled* for the AWS account/org
# (Control Tower / Organizations console, one-time, can't be done well from Terraform
# because there's no API to "turn on" Identity Center itself). Once enabled, everything
# below is Terraform-managed.
#
# Flow demonstrated in the video:
#   SSO user logs into the AWS access portal -> assumes the "EKSDeveloper" permission set
#   role -> runs `aws eks update-kubeconfig` using that SSO profile -> kubectl calls are
#   authenticated as that IAM role -> EKS access entry maps the role to a Kubernetes group
#   -> Kubernetes RBAC RoleBinding (k8s-rbac/) restricts that group to the `dev` namespace.

data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

resource "aws_ssoadmin_permission_set" "eks_developer" {
  name             = "EKSDeveloper"
  description      = "Scoped access for developers to view/use the private EKS cluster"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT4H"
}

# Minimal IAM permissions: allow calling EKS APIs needed to fetch cluster info + auth token.
# All *namespace-level* restriction happens in Kubernetes RBAC, not here -- IAM only gets
# the user in the door and identifies them to the cluster.
data "aws_iam_policy_document" "eks_developer" {
  statement {
    sid       = "EKSDescribeAndAuth"
    effect    = "Allow"
    actions   = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:AccessKubernetesApi",
    ]
    resources = [module.eks.cluster_arn]
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "eks_developer" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.eks_developer.arn
  inline_policy      = data.aws_iam_policy_document.eks_developer.json
}

# Look up the second user by username in Identity Center (must already exist / be
# synced from your IdP or created directly in Identity Center).
data "aws_identitystore_user" "second_user" {
  count             = var.second_user_identity_store_username == "" ? 0 : 1
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = var.second_user_identity_store_username
    }
  }
}

resource "aws_ssoadmin_account_assignment" "eks_developer" {
  count = var.second_user_identity_store_username == "" ? 0 : 1

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.eks_developer.arn

  principal_id   = data.aws_identitystore_user.second_user[0].user_id
  principal_type = "USER"

  target_id   = data.aws_caller_identity.current.account_id
  target_type = "AWS_ACCOUNT"
}

data "aws_caller_identity" "current" {}

# The permission set provisions an IAM role per account named like:
# AWSReservedSSO_EKSDeveloper_xxxxxxxxxxxxxxxx under
# arn:aws:iam::<account_id>:role/aws-reserved/sso.amazonaws.com/<region>/...
# That exact ARN only exists *after* the account assignment above has been provisioned,
# so in practice you either:
#   (a) apply once, read the role ARN from the console/CLI, then set `second_user_iam_arn`
#       and apply again so access-entries.tf can reference it, or
#   (b) use the aws_iam_roles data source with a name_regex to find it dynamically (below).
data "aws_iam_roles" "sso_eks_developer_role" {
  name_regex  = "AWSReservedSSO_EKSDeveloper_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"

  depends_on = [aws_ssoadmin_account_assignment.eks_developer]
}
