inputs = {
  env        = "devops-end-to-end"
  env_type   = "lab"
  aws_region = "eu-west-1"

  # Route 53
  zone_id       = "ergwegwergwergeqwr"
  domain_name   = "XXX.YYY.com"
  
  # Networking
  cidr   = "192.168.0.0/16"
  az_number    = 3

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
    }
  }     
}
