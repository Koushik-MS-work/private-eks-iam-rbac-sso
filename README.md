# Private EKS Cluster with IAM, Kubernetes RBAC & AWS SSO Access

Infrastructure-as-code project demonstrating a **private Amazon EKS cluster** with
secure, least-privilege multi-user access — built for a Senior AWS DevOps / Cloud
Engineer take-home assignment.

## Overview

A single external user (or IAM principal) shouldn't need broad cluster-admin rights
just to work inside one namespace. This project provisions a fully private EKS
cluster and wires up access so that:

- the cluster's Kubernetes API has **no public endpoint** at all,
- a second user authenticates through **AWS IAM Identity Center (AWS SSO)** rather
  than long-lived access keys,
- that user's access is scoped to a **single namespace** via Kubernetes RBAC, and
- every piece of infrastructure — networking, cluster, IAM, RBAC — is defined in
  **Terraform**, not clicked together in the console.

## Task requirements → implementation

| Requirement                            | Implementation                                                                      |
| -------------------------------------- | ----------------------------------------------------------------------------------- |
| Private EKS cluster                    | `terraform/eks.tf` — `cluster_endpoint_public_access = false`, private subnets only |
| Grant access to another user, securely | `terraform/access-entries.tf` — EKS Access Entries, no long-lived credentials       |
| IAM + Kubernetes RBAC per namespace    | `terraform/access-entries.tf` + `k8s-rbac/*.yaml`                                   |
| Access via AWS SSO                     | `terraform/iam-sso.tf` — IAM Identity Center permission set + account assignment    |
| Infrastructure via Terraform           | `terraform/` — built on `terraform-aws-modules/vpc` and `terraform-aws-modules/eks` |
| Architecture options with pros/cons    | [`docs/Architecture-Options.docx`](docs/Architecture-Options.docx)                  |

## Architecture

```
                         ┌─────────────────────────────────────────┐
                         │                  VPC                     │
                         │                                           │
   AWS SSO user  ──IAM──▶│  Private Subnets                         │
   (EKSDeveloper)        │   ┌───────────────┐   ┌─────────────────┐│
                         │   │  EKS Control   │   │  Managed Node   ││
   Bastion (SSM) ───────▶│   │  Plane (private│◀─▶│  Group          ││
                         │   │  endpoint only)│   │                 ││
                         │   └───────┬────────┘   └─────────────────┘│
                         │           │ RBAC-scoped by namespace       │
                         │   ┌───────┴────────────────────────────┐  │
                         │   │  dev   │  staging  │   prod         │  │
                         │   └────────────────────────────────────┘  │
                         │                                           │
                         │  VPC Interface Endpoints (ECR, STS, logs) │
                         └─────────────────────────────────────────┘
```

IAM answers _who is this_; Kubernetes RBAC answers _what can they touch_. The two are
deliberately kept separate — an EKS Access Entry maps an IAM principal to a Kubernetes
**group**, and a Kubernetes `Role`/`RoleBinding` scopes that group to one namespace.

## Tech stack

`Terraform` · `Amazon EKS` · `AWS IAM Identity Center (SSO)` · `Kubernetes RBAC` ·
`VPC / PrivateLink` · `AWS Systems Manager Session Manager`

## Repository structure

```
├── terraform/            # VPC, EKS, IAM/SSO, access entries, bastion
├── k8s-rbac/              # Namespace-scoped Role / RoleBinding manifests
├── docs/
│   └── Architecture-Options.docx   # Alternatives considered, pros/cons, decisions
├── README.md
```

## Quick start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in your account's values
terraform init
terraform plan
terraform apply

kubectl apply -f ../k8s-rbac/
```

Full prerequisites, exact console steps for IAM Identity Center, which variables to
change, and how to connect to the private endpoint are in **[SETUP.md](SETUP.md)**.

## Key design decisions

- **Fully private control plane**, reached via an SSM Session Manager bastion —
  no SSH keys, no open inbound ports, no public API endpoint.
- **EKS Access Entries** instead of the legacy `aws-auth` ConfigMap, for a validated,
  auditable IAM-to-Kubernetes mapping.
- **AWS IAM Identity Center** for the second user, so access is short-lived and
  centrally managed rather than a static credential.
- **Namespace-scoped RBAC**, one Kubernetes group per namespace/tier, so a
  compromised or misused identity can't reach beyond its intended scope.

See [`docs/Architecture-Options.docx`](docs/Architecture-Options.docx) for the full
comparison of alternatives considered for each of these decisions.
