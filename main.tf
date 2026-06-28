# ==========================================
# 0. VARIABLES & CORE CONFIGURATION
# ==========================================
variable "student_id" {
  type        = string
  default     = "alt-soe-o25-3603" 
}

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # REMOTE STATE MANAGEMENT (Section 4.1)
  # NOTE: We leave this commented out for the very first run.
  backend "s3" {
    bucket       = "bedrock-state-alt-soe-o25-3603" 
    key          = "capstone/terraform.tfstate"
    region       = "us-east-1"
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
# ==========================================
# 1. NETWORK LAYER (VPC)
# ==========================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "project-bedrock-vpc"
  cidr = "10.0.0.0/16"

  azs              = ["us-east-1a", "us-east-1b"]
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets  = ["10.0.11.0/24", "10.0.12.0/24"]
  database_subnets = ["10.0.21.0/24", "10.0.22.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true 
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# ==========================================
# 2. COMPUTE LAYER (AMAZON EKS CLUSTER)
# ==========================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.33.1" 

  cluster_name    = "project-bedrock-cluster"
  cluster_version = "1.34"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  cluster_endpoint_public_access = true
  cluster_enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  eks_managed_node_groups = {
    nodes = {
      desired_size   = 2
      min_size       = 1
      max_size       = 3
      instance_types = ["t3.medium"]

      # WE ADDED THIS NEW PIECE RIGHT HERE:
      iam_role_additional_policies = {
        CloudWatch = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }
    }
  }
}
# ==========================================
# 3. SECURE MANAGED DATA LAYER (RDS & DYNAMODB)
# ==========================================
resource "aws_security_group" "db_sg" {
  name        = "project-bedrock-db-sg"
  description = "Allow inbound database traffic from EKS nodes only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "MySQL from EKS Nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  ingress {
    description     = "PostgreSQL from EKS Nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "mysql" {
  allocated_storage      = 20
  identifier             = "project-bedrock-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "BedrockSecretPassword123!"
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
}

resource "aws_db_instance" "postgres" {
  allocated_storage      = 20
  identifier             = "project-bedrock-postgres"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  username               = "postgres"
  password               = "BedrockSecretPassword123!"
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
}

resource "aws_dynamodb_table" "carts" {
  name         = "project-bedrock-carts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# ==========================================
# 4. DEVELOPER SECURITY & RBAC ACCESS
# ==========================================
resource "aws_iam_user" "developer" {
  name = "bedrock-dev-view"
}

resource "aws_iam_user_policy_attachment" "console_read_only" {
  user       = aws_iam_user.developer.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_eks_access_entry" "dev_k8s_entry" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_user.developer.arn
  type          = "STANDARD"
}

resource "aws_eks_access_entry" "developer" {
  cluster_name      = "project-bedrock-cluster"
  principal_arn     = "arn:aws:iam::856802649206:user/bedrock-dev-view"
  kubernetes_groups = ["reader"]
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "dev_k8s_rbac" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy" 
  principal_arn = aws_iam_user.developer.arn

  access_scope {
    type       = "namespace"
    namespaces = ["retail-app"]
  }
}  

# ==========================================
# 5. SERVERLESS ASSET ENGINE (S3 + LAMBDA)
# ==========================================
resource "aws_s3_bucket" "assets" {
  bucket        = "bedrock-assets-${var.student_id}"
  force_destroy = true
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "bedrock-state-${var.student_id}"
  force_destroy = true
}

resource "aws_iam_user_policy" "developer_s3_upload" {
  name = "bedrock-dev-s3-upload"
  user = aws_iam_user.developer.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${aws_s3_bucket.assets.arn}/*"]
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "bedrock-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "bedrock-asset-processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.assets.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.assets.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# ==========================================
# 6. GRADING OUTPUT REQUIREMENTS
# ==========================================
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "region" {
  value = "us-east-1"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "assets_bucket_name" {
  value = aws_s3_bucket.assets.id
}

# Give starttech-devops-user full administrator access to the cluster
resource "aws_eks_access_entry" "admin_entry" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::856802649206:user/starttech-devops-user"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin_policy" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::856802649206:user/starttech-devops-user"

  access_scope {
    type = "cluster"
  }
}
# 1. Create the Developer IAM User
resource "aws_iam_user" "developer_user" {
  name = "bedrock-dev-view"
  tags = {
    Project = "karatu-2025-capstone"
  }
}

# 2. Attach ReadOnlyAccess so they can see things in the AWS Console
resource "aws_iam_user_policy_attachment" "dev_readonly" {
  user       = aws_iam_user.developer_user.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# 3. Generate Access Keys for this user (You will need to submit these!)
resource "aws_iam_access_key" "dev_key" {
  user = aws_iam_user.developer_user.name
}

# 4. Output the keys to your terminal so you can save them for grading
output "dev_iam_access_key_id" {
  value       = aws_iam_access_key.dev_key.id
  description = "Submit this as the Developer Access Key ID"
}

output "dev_iam_secret_access_key" {
  value     = aws_iam_access_key.dev_key.secret
  sensitive = true
}
# Give bedrock-dev-view read-only viewer access to the cluster
resource "aws_eks_access_entry" "viewer_entry" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_user.developer_user.arn
  type          = "STANDARD"
}
resource "aws_eks_access_policy_association" "viewer_policy" {
  cluster_name  = "project-bedrock-cluster"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  principal_arn = aws_iam_user.developer_user.arn # Ensure this matches your user's ARN

  access_scope {
    type       = "namespace"
    namespaces = ["retail-app"] 
  }
}  
# ===================================================
# AWS LOAD BALANCER CONTROLLER IAM ROLE (SECTION 4.2)
# ===================================================

data "aws_iam_policy_document" "lbc_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "lbc_role" {
  assume_role_policy = data.aws_iam_policy_document.lbc_assume_role.json
  name               = "AWSLoadBalancerControllerRole"

  tags = {
    Project = "karatu-2025-capstone"
  }
}

resource "aws_iam_role_policy_attachment" "lbc_policy_attach" {
  role       = aws_iam_role.lbc_role.name
  policy_arn = "arn:aws:iam::856802649206:policy/AWSLoadBalancerControllerIAMPolicy"
}

output "lbc_role_arn" {
  value = aws_iam_role.lbc_role.arn
}
# ==========================================
# DATABASE ENDPOINT OUTPUTS FOR APPLICATION
# ==========================================

output "mysql_endpoint" {
  value       = aws_db_instance.mysql.endpoint
  description = "Connect your Orders microservice to this MySQL address"
}

output "postgres_endpoint" {
  value       = aws_db_instance.postgres.endpoint
  description = "Connect your Catalog microservice to this PostgreSQL address"
}
# ===================================================
# LBC PERMISSION PATCH: DESCRIBE LISTENER ATTRIBUTES
# ===================================================

resource "aws_iam_policy" "lbc_patch" {
  name        = "AWSLoadBalancerControllerPatch"
  description = "Fixes missing listener attribute permissions for EKS ALB Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:ModifyListenerAttributes"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lbc_patch_attach" {
  role       = aws_iam_role.lbc_role.name
  policy_arn = aws_iam_policy.lbc_patch.arn
}
