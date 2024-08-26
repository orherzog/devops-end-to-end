locals {
  argocd_namespace = "argocd"
  install_argocd = lookup(var.eks_mng_settings.generic.addons.argocd, "enabled", false)
  use_local_cluster = lookup(var.eks_mng_settings.generic.addons.argocd, "use_local_cluster", true)
  remote_cluster_name = lookup(var.eks_mng_settings.generic.addons.argocd, "remote_cluster_name", "")
}

resource "kubernetes_service_account_v1" "ecr_credentials_sync" {
  count = local.install_argocd && local.use_local_cluster ? 1 : 0
  metadata {
    name      = "ecr-credentials-sync"
    namespace = local.argocd_namespace

    annotations = {
      "eks.amazonaws.com/role-arn" = module.argocd_irsa_role.iam_role_arn
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
    one(data.aws_iam_roles.AWSAdministratorAccess.arns),
  ]
  key_users = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/role-comm-it-trust",
    one(data.aws_iam_roles.AWSAdministratorAccess.arns),
    module.argocd_irsa_role.iam_role_arn,
  ]

  # Aliases
  aliases    = ["${var.env}/argocd/sops"]
  depends_on = [module.eks_blueprints_addons]
}
