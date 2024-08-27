inputs = {
  env        = "leumit-test"
  env_type   = "lab"
  aws_region = "eu-west-1"

  # Route 53
  zone_id       = "ergwegwergwergeqwr"
  domain_name   = "XXX.YYY.com"

  # Networking
  cidr          = "172.20.0.0/16"
  az_number     = 3
  create_public_subnet = false 

  # EKS
  eks_mng_settings = {
    generic = {
      per_az          = "false"
      az_qty          = 2
      capacity_type   = "SPOT"
      max_unavailable = 1
      min_size        = 0
      max_size        = 4
      desired_size    = 2
      ami_type        = "AL2_x86_64"
      instance_types  = ["t3.small"]
      volume_size     = 50
      iops            = 3000
      use_ami_id      = true
      addons = {
        karpenter = {
          enabled = true
        }
        argocd = {
          enabled = false
          use_local_cluster = false   # Boolean to determine if ArgoCD should use a local cluster
          use_remote_cluster = false  # If using a remote cluster, provide the cluster name here
          remote_cluster = {
            argocd_manange_cluster_name = ""  # The name of the cluster where argocd was installed
            argocd_manange_cluster_url = "" # The URL of the argocd (Should be accessable by the machine how run the terragrunt)
            argocd_manange_username = "" # The username of the argocd (Usually 'admin', But also can be SSO user)
            argocd_manange_password = "" # The password for the username that was specified
          }
        }
      }
    }
  }
}     
