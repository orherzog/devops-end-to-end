locals {
  argocd_namespace            = "argocd"
  install_argocd              = lookup(var.eks_mng_settings.generic.addons.argocd, "enabled", false)
  use_local_cluster           = lookup(var.eks_mng_settings.generic.addons.argocd, "use_local_cluster", false)
  use_remote_cluster          = lookup(var.eks_mng_settings.generic.addons.argocd, "use_remote_cluster", false)
  remote_cluster              = lookup(var.eks_mng_settings.generic.addons.argocd, "remote_cluster", {})
  argocd_manange_cluster_name = lookup(local.remote_cluster, "argocd_manange_cluster_name", "")
  argocd_manange_cluster_url  = lookup(local.remote_cluster, "argocd_manange_cluster_url", "")
  argocd_manange_username     = lookup(local.remote_cluster, "argocd_manange_username", "")
  argocd_manange_password     = lookup(local.remote_cluster, "argocd_manange_password", "")
  cluster_name                = "eks-${var.env}"
}

resource "kubernetes_service_account_v1" "ecr_credentials_sync" {
  count = local.install_argocd && local.use_local_cluster ? 1 : 0
  metadata {
    name      = "ecr-credentials-sync"
    namespace = local.argocd_namespace

    annotations = {
      "eks.amazonaws.com/role-arn" = module.argocd_irsa_role[0].iam_role_arn
    }
  }
  depends_on = [module.eks_blueprints_addons]
}

resource "kubernetes_role_v1" "ecr_credentials_sync" {
  count = local.install_argocd && local.use_local_cluster ? 1 : 0
  metadata {
    name      = "ecr-credentials-sync"
    namespace = local.argocd_namespace
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "create", "patch"]
  }
  depends_on = [module.eks_blueprints_addons]
}

resource "kubernetes_role_binding_v1" "ecr_credentials_sync" {
  count = local.install_argocd && local.use_local_cluster ? 1 : 0
  metadata {
    name      = "ecr-credentials-sync"
    namespace = local.argocd_namespace
  }

  role_ref {
    kind      = "Role"
    name      = kubernetes_role_v1.ecr_credentials_sync[0].metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.ecr_credentials_sync[0].metadata[0].name
    namespace = local.argocd_namespace
  }
  depends_on = [module.eks_blueprints_addons]
}

resource "kubernetes_cron_job_v1" "ecr_credentials_sync" {
  count = local.install_argocd && local.use_local_cluster ? 1 : 0
  metadata {
    name      = "ecr-credentials-sync"
    namespace = local.argocd_namespace
  }

  spec {
    schedule                      = "*/10 * * * *" # Run every 10 minutes
    successful_jobs_history_limit = 1

    job_template {
      metadata {
        name = "ecr-credentials-sync"
      }
      spec {
        template {
          metadata {
            name = "ecr-credentials-sync"
          }

          spec {
            restart_policy       = "Never"
            service_account_name = "ecr-credentials-sync"

            volume {
              name = "token"
              empty_dir {
                medium = "Memory"
              }
            }

            init_container {
              name              = "get-token"
              image             = "amazon/aws-cli"
              image_pull_policy = "IfNotPresent"

              env {
                name  = "REGION"
                value = var.aws_region # Replace with your AWS region
              }

              command = ["/bin/sh", "-ce", "aws ecr get-login-password --region ${var.aws_region} > /token/ecr-token"]

              volume_mount {
                mount_path = "/token"
                name       = "token"
              }
            }

            container {
              name              = "create-secret"
              image             = "bitnami/kubectl"
              image_pull_policy = "IfNotPresent"

              env {
                name  = "SECRET_NAME"
                value = "ecr-credentials"
              }

              env {
                name  = "ECR_REGISTRY"
                value = "${var.shared_services_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
                # Replace with your ECR registry URL
              }

              command = [
                "/bin/bash",
                "-ce",
                "kubectl -n argocd create secret docker-registry $SECRET_NAME --dry-run=client --docker-server=\"$ECR_REGISTRY\" --docker-username=AWS --docker-password=\"$(</token/ecr-token)\" -o yaml | kubectl apply -f - && cat <<EOF | kubectl apply -f -\napiVersion: v1\nkind: Secret\nmetadata:\n  name: argocd-ecr-helm-credentials\n  namespace: argocd\n  labels:\n    argocd.argoproj.io/secret-type: repository\nstringData:\n  username: AWS\n  password: $(</token/ecr-token)\n  enableOCI: \"true\"\n  name: \"ECR\"\n  type: \"helm\"\n  url: \"${var.shared_services_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com\"\nEOF"
              ]

              volume_mount {
                mount_path = "/token"
                name       = "token"
              }
            }
          }
        }
      }
    }
  }
  depends_on = [module.eks_blueprints_addons]
}

module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "2.0.1"
  
  count = local.install_argocd && local.use_local_cluster ? 1 : 0

  description = "ArgoCD helm-secrets SOPS key"
  key_usage   = "ENCRYPT_DECRYPT"

  # Policy
  key_administrators = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/role-comm-it-trust",
    element(data.aws_iam_roles.AWSAdministratorAccess.arns, 0),
  ]
  key_users = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/role-comm-it-trust",
    element(data.aws_iam_roles.AWSAdministratorAccess.arns, 0),
    module.argocd_irsa_role[0].iam_role_arn,
  ]

  # Aliases
  aliases    = ["${var.env}/argocd/sops"]
  depends_on = [module.eks_blueprints_addons]
}

# Check if the cluster exists in kubeconfig
data "external" "kubeconfig_check" {
  count = local.install_argocd && local.use_remote_cluster ? 1 : 0
  program = ["${path.module}/resources/scripts/check_kubeconfig.sh", local.argocd_manange_cluster_name]
}

# Log in to ArgoCD and add the cluster if the previous check was successful
data "external" "argocd_login_and_add" {
  count = local.install_argocd && local.use_remote_cluster ? 1 : 0
  depends_on = [data.external.kubeconfig_check]
  program = [
    "${path.module}/resources/scripts/argocd_login_and_add.sh",
    local.argocd_manange_cluster_url,
    local.argocd_manange_username,
    local.argocd_manange_password,
    module.eks.cluster_arn,
    local.cluster_name
  ]
}

# Output for kubeconfig check result
output "kubeconfig_check_result" {
  value = local.install_argocd && local.use_remote_cluster ? data.external.kubeconfig_check[0].result : null
}

# Output for argocd login and add result
output "argocd_login_and_add_result" {
  value = local.install_argocd && local.use_remote_cluster ? data.external.argocd_login_and_add[0].result : null
}