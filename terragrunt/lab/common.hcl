inputs = {
  allowed_account_ids     = ["581349712378"]

  # Tags
  common_tags = {
    environment-name     = "leumit-test",
    environment-type     = "lab",
    created-by           = "terraform",
    requested-by         = "orh",
    backup-policy        = "policy-name"
  }

  # # Networking
  # tgw_id                  = "tgw-0a1f337f47651fac0"
  # tgw_rtb_association_id  = "tgw-rtb-0c8fbd587743f0452"
  # tgw_rtb_propogation_ids = ["tgw-rtb-07cae0c7a7e73b288"]

  shared_services_account_id = "581349712378"
  ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
  
  # # Provider Configuration
  # aws_region              = "eu-central-1"
  # aws_profile             = "commit-prof"
  # common_parameters       = {

  # }

}
