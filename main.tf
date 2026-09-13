terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "devsecops-tfstate-local"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true

    # Credenciais dummy para autenticação no LocalStack
    access_key = "test"
    secret_key = "test"

    # Sintaxe moderna que elimina os avisos de deprecation
    endpoints = {
      s3       = "http://localhost:4566"
      dynamodb = "http://localhost:4566"
      iam      = "http://localhost:4566"
      sts      = "http://localhost:4566"
    }

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}


provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  # Aponta todos os serviços para o endpoint único do LocalStack
  endpoints {
    cloudwatchlogs = var.localstack_endpoint
    ecs            = var.localstack_endpoint
    ec2            = var.localstack_endpoint
    kms            = var.localstack_endpoint
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "localstack_endpoint" {
  type        = string
  default     = "http://localhost:4566"
  description = "Endpoint do LocalStack"
}

# 1. VPC criada localmente para viabilizar o Security Group sem erros
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# 2. Chave KMS local para atender aos requisitos de conformidade/Checkov
resource "aws_kms_key" "logs_key" {
  description             = "Chave KMS para criptografia de logs no LocalStack"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Environment = var.environment
  }
}

# 3. CloudWatch Log Group com KMS atrelado
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/ecs/${var.environment}-api"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs_key.arn

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# # 4. Cluster ECS
# resource "aws_ecs_cluster" "main" {
#   name = "${var.environment}-cluster"

#   setting {
#     name  = "containerInsights"
#     value = "enabled"
#   }
# }

# 5. Security Group seguro associado à VPC local
resource "aws_security_group" "ecs_sg" {
  name        = "${var.environment}-ecs-sg"
  description = "Acesso seguro para o servico ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Acesso HTTP restrito a rede interna"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "Saida irrestrita de rede"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
  }
}