data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.eks_version}-v*"]
  }
}
locals {
  mng_list = flatten([
    for name, settings in var.eks_mng_settings :[
      for  index, az in settings.per_az == "true" ? range(1, settings.az_qty+1) : ["1"] : {
        key   = settings.per_az ? "${name}-az${az}" : name
        value = {
          name          = settings.per_az ? "mng-eks-${var.env}-${name}-az${az}" : "mng-eks-${var.env}-${name}"
          subnet_ids    = settings.per_az ? [var.subnet_ids[index]] : try(slice(var.subnet_ids, 0, settings.az_qty), [])
          capacity_type = settings.capacity_type
          labels        = {
            environment        = var.env
            capacity_type      = lower(settings.capacity_type)
          }
          # ASG
          min_size      = settings.min_size
          max_size      = settings.max_size
          desired_size  = settings.desired_size
          update_config = {
            max_unavailable = settings.max_unavailable
          }

          launch_template_name = settings.per_az ? "lt-${var.env}-eks-${name}-az${az}" : "lt-${var.env}-eks-${name}"
          launch_template_tags = merge(var.common_tags, {
            Name = settings.per_az ? "i-${var.env}-eks-${name}-az${az}" : "i-${var.env}-eks-${name}"
          })
          iam_role_name         = settings.per_az ? "role-${var.env}-eks-mng-${name}-az${az}" : "role-${var.env}-eks-mng-${name}"
          ami_type              = settings.use_ami_id ? null : settings.ami_type
          ami_id                = settings.use_ami_id ? data.aws_ami.eks_default.image_id : null
          enable_bootstrap_user_data = settings.use_ami_id ? true : false
          instance_types        = settings.instance_types
          block_device_mappings = {
            xvda = {
              device_name = "/dev/xvda"
              ebs         = {
                volume_size           = settings.volume_size
                iops                  = settings.iops
                volume_type           = "gp3"
                encrypted             = true
                # todo: specify custom key for encryption?
                # kms_key_id            = aws_kms_key.aws-ebs-csi-driver.arn
                delete_on_termination = true
              }
            }
          }
        }
      }
    ]
  ])
  mng = {for v in local.mng_list : v.key => v.value}
  # devops_role_arn = [
  #   for parts in [for arn in data.aws_iam_roles.roles.arns : split("/", arn)] :
  #   format("%s/%s", parts[0], element(parts, length(parts) - 1))
  # ]
}
