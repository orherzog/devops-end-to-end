################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.12.0"

  name = var.env
  cidr = var.cidr

  azs = slice(data.aws_availability_zones.available.names, 0, var.az_number)

  public_subnets   = local.public_subnet_cidrs
  private_subnets  = local.private_subnet_cidrs
  database_subnets = local.database_subnet_cidrs


  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  # VPC Flow Logs (Cloudwatch log group and IAM role will be created)
  vpc_flow_log_iam_role_name            = "vpc-flow-log-role-${var.env}"
  vpc_flow_log_iam_role_use_name_prefix = false
  enable_flow_log                       = true
  create_flow_log_cloudwatch_log_group  = true
  create_flow_log_cloudwatch_iam_role   = true
  flow_log_max_aggregation_interval     = 60
}

resource "aws_ec2_managed_prefix_list" "client_subnets" {
  name           = "All client CIDR-s"
  address_family = "IPv4"
  max_entries    = 5

  entry {
    cidr        = "10.110.0.0/16"
    description = "Primary"
  }

  entry {
    cidr        = "10.111.0.0/16"
    description = "Secondary"
  }

  entry {
    cidr        = "0.0.0.0/0"
    description = "Primary"
  }
}