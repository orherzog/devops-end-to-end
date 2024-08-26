output "eks" {
  value = module.eks
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "aws_admin_access_role_arn" {
  value = local.AWSAdministratorAccess_arn
}