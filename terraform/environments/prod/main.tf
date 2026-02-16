# Production Environment Configuration

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Recommended: Configure S3 backend for state management in production
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "production"
      ManagedBy   = "terraform"
      Project     = "go-app"
      CostCenter  = "engineering"
    }
  }
}

# Local variables
locals {
  environment  = "prod"
  cluster_name = "${var.project_name}-${local.environment}"
  
  common_tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    CostCenter  = "engineering"
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  cluster_name       = local.cluster_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  tags               = local.common_tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  cluster_name        = local.cluster_name
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_disk_size      = var.node_disk_size
  tags                = local.common_tags

  depends_on = [module.vpc]
}

# IRSA Module
module "irsa" {
  source = "../../modules/irsa"

  cluster_name         = local.cluster_name
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  namespace            = var.app_namespace
  service_account_name = var.service_account_name
  tags                 = local.common_tags

  depends_on = [module.eks]
}
