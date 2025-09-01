module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.name_prefix}-eks"
  cluster_version = "1.29"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  cluster_endpoint_public_access  = true  # so i can run kubectl from my laptop
  cluster_endpoint_private_access = true  # so nodes inside VPC can also talk

  # ✅ Add proper IAM configuration for cluster
  create_iam_role = true
  iam_role_use_name_prefix = false
  
  # ✅ Enable cluster creator admin permissions (automatically adds creator to aws-auth)
  enable_cluster_creator_admin_permissions = true



  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.large"]
      desired_size   = 2
      min_size       = 2
      max_size       = 3
      subnet_ids     = module.vpc.private_subnets
      
      # ✅ Add proper IAM configuration for node group
      create_iam_role = true
      iam_role_use_name_prefix = false
      
      # ✅ Ensure proper policies are attached to node group (as a map)
      iam_role_additional_policies = {
        AmazonEKSWorkerNodePolicy = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEKS_CNI_Policy = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }
    }
  }
}
