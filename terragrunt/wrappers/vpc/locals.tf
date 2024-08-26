locals {
  # Calculate subnet CIDR blocks
  public_subnet_cidrs   = [for i in range(var.az_number) : cidrsubnet(var.cidr, 4, i)]
  private_subnet_cidrs  = [for i in range(var.az_number) : cidrsubnet(var.cidr, 4, i + var.az_number)]
  database_subnet_cidrs = [for i in range(var.az_number) : cidrsubnet(var.cidr, 4, i + 2 * var.az_number)]
}