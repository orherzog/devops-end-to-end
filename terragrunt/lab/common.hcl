inputs = {
  allowed_account_ids     = ["581349712378"]

  # Tags
  common_tags = {
    environment-name     = "lab",
    environment-type     = "lab-env",
    created-by           = "terraform",
    requested-by         = "orh",
    backup-policy        = "policy-name"
  }

  # Networking
  // tgw_id                  = "tgw-079092d4b2b62c534"
  // tgw_rtb_association_id  = "tgw-rtb-064f15e0f1da4fdee"
  // tgw_rtb_propogation_ids = ["tgw-rtb-0d5a36ba4e05cd94f", "tgw-rtb-0d38e05425541ef65"]

  # shared_services_account_id = "058264117946"
  // ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
  
  # Provider Configuration
  aws_region              = "eu-west-1"
  # aws_profile             = "wavebl-shared"
  common_parameters       = {

  }
}
