################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.12.0"

  name = var.env
  cidr = var.cidr

  azs = slice(data.aws_availability_zones.available.names, 0, var.az_number)

  private_subnets  = local.private_subnet_cidrs
  database_subnets = local.database_subnet_cidrs
  public_subnets   = local.create_public_subnet ? local.public_subnet_cidrs : []

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = local.create_public_subnet 
  single_nat_gateway = local.create_public_subnet 

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

# Endpoints Security Group
module "sg-vpc-endpoint" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"
  count   = var.enable_vpc_endpoint ? 1 : 0
  name    = "sgr-${var.env}-vpc-endpoints"

  description     = "Security group for VPC endpoints"
  vpc_id          = module.vpc.vpc_id
  use_name_prefix = false

  ingress_cidr_blocks     = [var.cidr]
  ingress_rules           = ["all-all"]
  egress_cidr_blocks      = ["0.0.0.0/0"]
  egress_ipv6_cidr_blocks = []
  egress_rules            = ["all-all"]

  tags = {
    Name           = "sgr-${var.env}-vpc-endpoints"
    service        = "networking"
    module_version = "v0.0.0"
  }
}

# VPC Endpoints
module "vpc-endpoints" {
  source             = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version            = "5.1.2"
  count              = var.enable_vpc_endpoint ? 1 : 0
  vpc_id             = module.vpc.vpc_id
  security_group_ids = module.sg-vpc-endpoint[*].security_group_id
  endpoints = {
    s3 = {
      service      = "s3"
      service_type = "Gateway"
      route_table_ids = flatten([
        module.vpc.private_route_table_ids, module.vpc.public_route_table_ids, module.vpc.database_route_table_ids
      ])
      tags = { Name = "vpce-gateway-${var.env}-s3" }
    },
    logs = {
      service             = "logs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags                = { Name = "vpce-interface-${var.env}-logs" }
    },
    ecr-api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags                = { Name = "vpce-interface-${var.env}-ecr-api" }
    },
    ecr-dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags                = { Name = "vpce-interface-${var.env}-ecr-dkr" }
    },
    aps-workspaces = {
      service             = "aps-workspaces"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags                = { Name = "vpce-interface-${var.env}-aps-workspaces" }
    }
  }
  tags = {
    service        = "networking"
    module_version = "v0.0.0"
  }
}