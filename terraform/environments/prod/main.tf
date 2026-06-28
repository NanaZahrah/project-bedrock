terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket = "project-bedrock-tfstate-alt-soe-025-3603"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project = "karatu-2025-capstone"
    }
  }
}

locals {
  cluster_name = "project-bedrock-cluster"
  vpc_name     = "project-bedrock-vpc"
  student_id   = "alt-soe-025-3603"
  tags = {
    Project = "karatu-2025-capstone"
  }
}

module "vpc" {
  source       = "../../modules/vpc"
  vpc_name     = local.vpc_name
  vpc_cidr     = "10.0.0.0/16"
  cluster_name = local.cluster_name
  tags         = local.tags
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = local.cluster_name
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_type = "t3.medium"
  node_desired       = 2
  node_min           = 1
  node_max           = 3
  tags               = local.tags
}

module "rds_mysql" {
  source                = "../../modules/rds"
  identifier            = "bedrock-mysql"
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  eks_security_group_id = module.eks.cluster_security_group_id
  engine                = "mysql"
  engine_version        = "8.0"
  db_name               = "ordersdb"
  db_username           = "dbadmin"
  db_password           = "BedrockMySQL2025!"
  db_port               = 3306
  tags                  = local.tags
}

module "rds_postgres" {
  source                = "../../modules/rds"
  identifier            = "bedrock-postgres"
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  eks_security_group_id = module.eks.cluster_security_group_id
  engine                = "postgres"
  engine_version        = "15"
  db_name               = "catalogdb"
  db_username           = "dbadmin"
  db_password           = "BedrockPG2025!"
  db_port               = 5432
  tags                  = local.tags
}

module "dynamodb" {
  source     = "../../modules/dynamodb"
  table_name = "bedrock-checkout"
  tags       = local.tags
}

module "lambda" {
  source        = "../../modules/lambda"
  function_name = "bedrock-asset-processor"
  bucket_arn    = "arn:aws:s3:::bedrock-assets-${local.student_id}"
  tags          = local.tags
}

module "s3" {
  source               = "../../modules/s3"
  bucket_name          = "bedrock-assets-${local.student_id}"
  lambda_arn           = module.lambda.lambda_arn
  lambda_permission_id = module.lambda.lambda_permission_id
  tags                 = local.tags
}

module "iam" {
  source            = "../../modules/iam"
  dev_user_name     = "bedrock-dev-view"
  assets_bucket_arn = module.s3.bucket_arn
  tags              = local.tags
}
