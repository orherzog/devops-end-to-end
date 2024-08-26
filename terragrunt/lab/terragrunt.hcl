generate "main_providers" {
  path      = "main_providers.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = var.aws_region
  assume_role {
    role_arn = "arn:aws:iam::${get_aws_account_id()}:role/devops-end-to-end-terragrunt"
  }
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = var.common_tags
  }
}

provider "aws" {
  alias  = "eu-central-1"
  region = "eu-central-1"

  default_tags {
    tags = var.common_tags
  }
}

variable "aws_region" {
  description = "AWS region to create infrastructure in"
  type        = string
}

variable "allowed_account_ids" {
  description = "List of allowed AWS account ids to create infrastructure in"
  type        = list(string)
}

variable "common_parameters" {
  description = "Map of common parameters shared across all infrastructure resources (eg, domain names)"
  type        = map(string)
  default     = {}
}
EOF
}

remote_state {
  backend      = "s3"
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))

  disable_dependency_optimization = true

  generate = {
    path      = "_backend.tf"
    if_exists = "overwrite"
  }

  config = {
    encrypt        = true
    region         = "eu-central-1"
    key            = format("lab/%s/terraform.tfstate", path_relative_to_include())
    bucket         = format("terraform-state-%s", get_aws_account_id())
    dynamodb_table = format("terraform-state-%s", get_aws_account_id())
  }
}