locals {
  create_public_subnet = var.create_public_subnet
  
  # Calculate subnet CIDR blocks
  private_subnet_cidrs = [for i in range(var.az_number) : cidrsubnet(var.cidr, 4, i)]
  database_subnet_cidrs = [for i in range(var.az_number) : cidrsubnet(var.cidr, 4, i + var.az_number)]

  # Public subnets (only if needed)
  public_subnet_cidrs = local.create_public_subnet ? [for i in range(var.az_number) : cidrsubnet(var.cidr, 4, i + 2 * var.az_number)] : []
}