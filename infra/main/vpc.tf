module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name               = "${var.name_prefix}-vpc"
  cidr               = "10.0.0.0/16"
  azs                = ["${var.region}a", "${var.region}b"]
  public_subnets     = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnets    = ["10.0.10.0/24", "10.0.11.0/24"]
  enable_nat_gateway = true
}