resource "kubectl_manifest" "karpenter_default_ec2_node_class" {
  yaml_body = <<YAML
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: "${module.eks_blueprints_addons.karpenter.node_iam_role_name}"
  amiFamily: AL2 
  securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: "eks-${var.env}"
  subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: "eks-${var.env}"
  tags:
    karpenter-node-pool-name: default
    intent: apps
    karpenter.sh/discovery: "eks-${var.env}"
    Name: "i-${var.env}-eks-karpenter-default"
YAML
  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
  ]
}

# Default NodePool current leumit Spot (FromGithub)
resource "kubectl_manifest" "karpenter_default_node_pool" {
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default 
spec:
  template:
    metadata:
      labels:
        app: backoffice
    spec:
      taints:
        - key: app/backoffice
          effect: NoSchedule  
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["4", "8", "16", "32"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["r6a"]
      nodeClassRef:
        name: default
      kubelet:
        containerRuntime: containerd
        maxPods: 30
        limits:
          cpu: 1000
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 300s
YAML
  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
    kubectl_manifest.karpenter_default_node_pool,
  ]
}

# resource "kubectl_manifest" "karpenter_default_node_pool" {
#   yaml_body = <<YAML
# apiVersion: karpenter.sh/v1beta1
# kind: NodePool
# metadata:
#   name: default 
# spec:  
#   template:
#     metadata:
#       labels:
#         intent: apps
#     spec:
#       requirements:
#         - key: kubernetes.io/arch
#           operator: In
#           values: ["amd64"]
#         - key: "karpenter.k8s.aws/instance-cpu"
#           operator: In
#           values: ["4", "8", "16", "32"]
#         - key: karpenter.sh/capacity-type
#           operator: In
#           values: [ "on-demand"]
#         - key: karpenter.k8s.aws/instance-category
#           operator: In
#           values: ["c", "m", "r"]
#       nodeClassRef:
#         name: default
#       kubelet:
#         containerRuntime: containerd
#         maxPods: 110
#         limits:
#           cpu: 1000
#   disruption:
#     consolidationPolicy: WhenEmpty
#     consolidateAfter: 300s


