data "aws_caller_identity" "current" {}
data "aws_default_tags" "this" {}

# data "aws_autoscaling_groups" "managed_node_groups_autoscaling_groups" {
#   names = module.eks.eks_managed_node_groups_autoscaling_group_names
# }

data "aws_iam_roles" "bastion_role" {
  name_regex  = "i-bastion_ec2*"
}

data "aws_iam_roles" "AWSAdministratorAccess" {
  name_regex  = "AWSReservedSSO_AWSAdministratorAccess*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}
locals { 
  AWSAdministratorAccess_arn = length(data.aws_iam_roles.AWSAdministratorAccess.arns) > 0 ? tolist(data.aws_iam_roles.AWSAdministratorAccess.arns)[0] : null 
}