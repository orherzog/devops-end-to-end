resource "aws_kms_key" "aws-ebs-csi-driver" {
  description = "KMS for aws ebs csi driver"
}

resource "aws_kms_key_policy" "aws-ebs-csi-driver" {
  key_id = aws_kms_key.aws-ebs-csi-driver.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "key-default-1",
    "Statement" : [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        "Sid" : "KeyUsage",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "${module.ebs_csi_irsa_role.iam_role_arn}"
        },
        "Action" : [
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Encrypt",
          "kms:DescribeKey",
          "kms:Decrypt",
          "kms:CreateGrant"
        ],
        "Resource" : "*"
      }
    ]
  })
}

module "eks" {
  # TODO: enable secrets encryption
  source  = "terraform-aws-modules/eks/aws"
  version = "20.2.1"

  cluster_name                    = "eks-${var.env}"
  cluster_version                 = var.eks_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false
  vpc_id                          = var.vpc_id
  subnet_ids                      = var.subnet_ids

  cluster_security_group_name            = "sgr-${var.env}-eks-cluster"
  cluster_security_group_use_name_prefix = false
  cluster_security_group_description     = "EKS Cluster security group"
  cluster_security_group_additional_rules = {
    ingress-https = {
      description = "Access from Client subnets prefix list to cluster api endpoint"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      prefix_list_ids = [var.client_prefix_list]
      # source_security_group_id  = var.security_group_instance
    }

    ingress-ssh = {
      description = "Access for SSH"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      type        = "ingress"
      prefix_list_ids = [var.client_prefix_list]
    }
  }

  iam_role_name            = "role-${var.env}-eks-cluster"
  iam_role_use_name_prefix = false

  enable_cluster_creator_admin_permissions = false

  access_entries = {
    # One access entry with a policy associated
    admin_sso_role = {
      kubernetes_groups = []
      principal_arn     = local.AWSAdministratorAccess_arn

      policy_associations = {
        single = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    # bastion_role = {
    #   kubernetes_groups = []
    #   principal_arn     = data.aws_iam_roles.bastion_role.arns

    #   policy_associations = {
    #     single = {
    #       policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    #       access_scope = {
    #         type       = "cluster"
    #       }
    #     }
    #   }
    # }

    karpenter_role = {
      # kubernetes_groups = ["system:nodes", "system:bootstrappers"]
      # user_name         = "system:node:{{EC2PrivateDNSName}}"
      type          = "EC2_LINUX"
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${module.eks_blueprints_addons.karpenter.node_iam_role_name}"

      # policy_associations = {
      #   single = {
      #     policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      #     access_scope = {
      #       type       = "cluster"
      #     }
      #   }
      # }
    }
    # ex-multiple = {
    #   kubernetes_groups = []
    #   principal_arn     = aws_iam_role.this["multiple"].arn

    #   policy_associations = {
    #     ex-one = {
    #       policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
    #       access_scope = {
    #         namespaces = ["default"]
    #         type       = "namespace"
    #       }
    #     }
    #     ex-two = {
    #       policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
    #       access_scope = {
    #         type = "cluster"
    #       }
    #     }
    #   }
    # }
  }

  node_security_group_additional_rules = {
    egress_all = {
      description      = "!!Node all egress!!"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

    ingress_all_vpc = {
      description = "!!Node all ingress from vpc!!"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      cidr_blocks = [var.cidr]
    }
    ingress_self_all = {
      description = "!!Node to node all ports/protocols!!"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # ingress_mng_all = {
    #   description = "OpenVPN Access"
    #   protocol    = "tcp"
    #   from_port   = 0
    #   to_port     = 0
    #   type        = "ingress"
    #   cidr_blocks = [var.shared_service_vpc_cidr]
    # }
  }
  node_security_group_tags = { "karpenter.sh/discovery" = "eks-${var.env}" }
  eks_managed_node_group_defaults = {
    use_name_prefix                        = true
    create_launch_template                 = true
    launch_template_use_name_prefix        = true
    iam_role_use_name_prefix               = true
    update_launch_template_default_version = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
    capacity_type = "ON_DEMAND"
    # See issue https://github.com/awslabs/amazon-eks-ami/issues/844
    # pre_bootstrap_user_data = <<-EOT
    #   #!/bin/bash
    #   set -ex
    #   cat <<-EOF > /etc/profile.d/bootstrap.sh
    #   export CONTAINER_RUNTIME="containerd"
    #   export USE_MAX_PODS=false
    #   export KUBELET_EXTRA_ARGS="--max-pods=120"
    #   EOF
    #   # Source extra environment variables in bootstrap script
    #   sed -i '/^set -o errexit/a\\nsource /etc/profile.d/bootstrap.sh' /etc/eks/bootstrap.sh
    # EOT
    pre_bootstrap_user_data = <<-EOT
      #!/bin/bash
      set -ex
      cat <<-EOF > /etc/profile.d/bootstrap.sh
        # This is the magic that permits max-pods computation to succeed
        export USE_MAX_PODS=false
        export KUBELET_EXTRA_ARGS="--max-pods=110"
        export CNI_PREFIX_DELEGATION_ENABLED=true
      EOF
      # Source extra environment variables in bootstrap script
      sed -i '/^set -o errexit/a\\nsource /etc/profile.d/bootstrap.sh' /etc/eks/bootstrap.sh
    EOT


  }

  eks_managed_node_groups = local.mng

  tags = {
    service        = "eks",
    module_version = "v0.0.0"
  }
}