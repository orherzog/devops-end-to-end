variable "env" {
    default = "env"
    description = "Environment name"
    type = string
}
variable "cidr" {
    default = "192.168.0.0/16"
    description = "CIDR block for VPC"
    type = string
}
variable "az_number" {
    default = 3
    description = "Number of availability zones to use"
    type = number
}

variable "enable_vpc_endpoint" {
  type    = bool
  default = true
}
variable "common_tags" { type = map(string) }