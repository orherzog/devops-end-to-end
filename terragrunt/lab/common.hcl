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
  
  # Provider Configuration
  aws_region              = "eu-west-1"
  common_parameters       = {

  }
}
