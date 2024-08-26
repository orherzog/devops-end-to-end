data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.us-east-1
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.12.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  create_delay_dependencies = [for prof in module.eks.eks_managed_node_groups : prof.node_group_arn]

  ## EKS ADDONS
  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      service_account_role_arn = module.vpc_cni_ipv4_irsa_role.iam_role_arn
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    kube-proxy = {
      most_recent = true
    }
    # aws-efs-csi-driver = {
    #   most_recent = true
    #   service_account_role_arn = module.efs_csi_irsa_role.iam_role_arn
    # }
    # aws-mountpoint-s3-csi-driver = {
    #   most_recent = true
    #   service_account_role_arn = module.s3_csi_irsa_role.iam_role_arn
    # }
  }

  # LOAD BALANCER CONTROLLER
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    chart_version = "1.5.4"
  }

  # NODE TERMINATION HANDLER
  # enable_aws_node_termination_handler = true
  # aws_node_termination_handler        = {
  #   chart_version = "0.21.0"
  # }
  # aws_node_termination_handler_asg_arns = data.aws_autoscaling_groups.managed_node_groups_autoscaling_groups.arns

  ## METRICS SERVER
  enable_metrics_server = true
  metrics_server = {
    chart_version = "3.10.0"
  }

  ## KARPENTER
  enable_karpenter = true
  karpenter = {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
  }
  karpenter_enable_spot_termination          = true
  karpenter_enable_instance_profile_creation = true
  karpenter_node = {
    iam_role_use_name_prefix = false
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }

  ## EXTERNAL-SECRET
  enable_external_secrets = false

  ## ArgoCD
  enable_argocd = local.install_argocd && local.use_local_cluster ? true : false
  argocd = {
    name          = "argocd"
    namespace     = local.argocd_namespace
    chart_version = "5.46.8"
    values = [
      templatefile("./resources/values/argocd.yaml", {
        common_tags             = data.aws_default_tags.this.tags
        ssl_policy              = var.ssl_policy
        argocd_host             = "argocd.local" #${local.system_dns_zone}"
        argocd_password         = local.install_argocd ? random_password.argocd_admin_password[0].result : ""
        argocd_repo_server_irsa = module.argocd_irsa_role.iam_role_arn
      })
    ]
  }

  ## EXTERNAL DNS
  ## External DNS
  enable_external_dns = false
  external_dns = {
    chart_version = "1.13.0"
  }
  external_dns_route53_zone_arns = ["arn:aws:route53:::hostedzone/${var.zone_id}"]
  ## Prometheus Stack
  enable_kube_prometheus_stack = false
}

resource "random_password" "argocd_admin_password" {
  count  = local.install_argocd && local.use_local_cluster ? 1 : 0
  length = 32
}

module "parameter_store_secrets" {
  count  = local.install_argocd && local.use_local_cluster ? 1 : 0
  source = "terraform-aws-modules/ssm-parameter/aws"

  name        = "argocd_admin_password"
  value       = random_password.argocd_admin_password[0].result
  secure_type = true
}


