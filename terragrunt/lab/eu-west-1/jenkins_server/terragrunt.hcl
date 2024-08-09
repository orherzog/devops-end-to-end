terraform {
  source = "github.com/orherzog/tf-modules//cicd/jenkins?ref=main"
}

include {
  path = find_in_parent_folders()
}

dependency "networking" {
  config_path = "../networking"
}

locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl")).inputs
  product_vars = read_terragrunt_config(find_in_parent_folders("product.hcl"), {inputs = {}}).inputs
}


inputs = merge(
  local.common_vars,
  local.product_vars,
  {
    vpc_id         = dependency.networking.outputs.vpc_id
    subnet_id      = dependency.networking.outputs.public_subnets[0]
  }
)
