variable "env" {}
variable "env_type" {}
variable "vpc_id" {}
variable "cidr" {}
variable "common_tags" { type = map(string) }
variable "subnet_ids" { type = list(string) }
variable "eks_mng_settings" { type = any }
variable "domain_name" {}
variable "zone_id" {}
variable "eks_version" {
  type    = string
  default = "1.30"
}
#variable "secrets" {type = any}
#variable "iam_role_instance" {}
#variable "storage_layer" {type = any}

variable "shared_services_account_id" {}
variable "ssl_policy" {}
variable "client_prefix_list" {}