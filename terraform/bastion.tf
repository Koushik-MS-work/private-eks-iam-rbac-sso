# Optional but recommended: a bastion with NO public IP and NO open inbound ports,
# reached only via SSM Session Manager. This is what lets you run kubectl/terraform
# against the private EKS endpoint from your own laptop's terminal (via `aws ssm
# start-session`, which tunnels through the AWS API, not through an open port).
#
# Toggle with var.create_bastion; defaults to true since the cluster is private-only
# by default and you need *some* way in.

variable "create_bastion" {
  description = "Whether to create an SSM-only bastion EC2 instance inside the private subnets"
  type        = bool
  default     = true
}

data "aws_ami" "al2023" {
  count       = var.create_bastion ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2*-x86_64"]
  }
}

resource "aws_security_group" "bastion" {
  count       = var.create_bastion ? 1 : 0
  name        = "${var.cluster_name}-bastion-sg"
  description = "Bastion SG - egress only, no inbound rules at all (reached via SSM, not SSH)"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "cluster_from_bastion" {
  count                    = var.create_bastion ? 1 : 0
  description              = "Allow bastion to reach the private EKS API endpoint"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = aws_security_group.bastion[0].id
}

resource "aws_iam_role" "bastion" {
  count = var.create_bastion ? 1 : 0
  name  = "${var.cluster_name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Lets SSM Session Manager connect to the instance (no SSH key needed at all).
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  count      = var.create_bastion ? 1 : 0
  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Lets the bastion role call the AWS-side EKS APIs needed to generate a kubeconfig
# (`aws eks update-kubeconfig` calls eks:DescribeCluster). This is plain IAM and is
# entirely separate from the EKS access entry below -- the access entry controls
# what the role can do *inside* the cluster once authenticated; this controls whether
# it can even discover/describe the cluster via the AWS API in the first place.
data "aws_iam_policy_document" "bastion_eks_describe" {
  count = var.create_bastion ? 1 : 0

  statement {
    sid    = "EKSDescribeAndAuth"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:AccessKubernetesApi",
    ]
    resources = [module.eks.cluster_arn]
  }
}

resource "aws_iam_role_policy" "bastion_eks_describe" {
  count  = var.create_bastion ? 1 : 0
  name   = "${var.cluster_name}-bastion-eks-describe"
  role   = aws_iam_role.bastion[0].id
  policy = data.aws_iam_policy_document.bastion_eks_describe[0].json
}

# Lets whoever is logged into the bastion run kubectl as a cluster admin
# (the bastion's instance role is added to the cluster the same way the second
# user is -- via an EKS access entry -- rather than by using long-lived keys).
resource "aws_eks_access_entry" "bastion_admin" {
  count         = var.create_bastion ? 1 : 0
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.bastion[0].arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  count         = var.create_bastion ? 1 : 0
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.bastion[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_iam_instance_profile" "bastion" {
  count = var.create_bastion ? 1 : 0
  name  = "${var.cluster_name}-bastion-profile"
  role  = aws_iam_role.bastion[0].name
}

resource "aws_instance" "bastion" {
  count                  = var.create_bastion ? 1 : 0
  ami                    = data.aws_ami.al2023[0].id
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.private_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.bastion[0].name
  vpc_security_group_ids = [aws_security_group.bastion[0].id]

  # Installs kubectl + the AWS CLI already-present on AL2023, so it's ready to use
  # the moment you connect via Session Manager.
  user_data = <<-EOF
    #!/bin/bash
    curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.34.6/2026-04-08/bin/linux/amd64/kubectl
    chmod +x kubectl
    mv kubectl /usr/local/bin/
  EOF

  tags = { Name = "${var.cluster_name}-bastion" }
}

output "bastion_instance_id" {
  value = var.create_bastion ? aws_instance.bastion[0].id : null
}
