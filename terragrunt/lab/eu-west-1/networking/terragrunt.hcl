terraform {
  source = "github.com/orherzog/tf-modules//networking/vpc?ref=main"
}

include {
  path = find_in_parent_folders()
}

locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl")).inputs
  product_vars = read_terragrunt_config(find_in_parent_folders("product.hcl"), {inputs = {}}).inputs
}


inputs = merge(
  local.common_vars,
  local.product_vars,
  {

  }
)
