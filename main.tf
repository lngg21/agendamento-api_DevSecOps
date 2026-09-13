terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "devsecops-tfstate-local"
    key          = "staging/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # substitui dynamodb_table

    access_key = "test"
    secret_key = "test"

    endpoints = {
      s3  = "http://localhost:4566"
      iam = "http://localhost:4566"
      sts = "http://localhost:4566"
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
    ec2            = var.localstack_endpoint
    kms            = var.localstack_endpoint
    sts            = var.localstack_endpoint
    iam            = var.localstack_endpoint
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

# ---------------------------------------------------------
# VPC & Networking Seguro
# ---------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  #checkov:skip=CKV2_AWS_11:Flow logs dispensados em ambiente de laboratorio/LocalStack

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# CKV2_AWS_12: Neutraliza o Default Security Group da VPC
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-default-sg-disabled"
    Environment = var.environment
  }
}

# Dados da conta para evitar uso de wildcard '*' no KMS Principal
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------
# KMS Key com Policy Explícita sem Wildcard (CKV2_AWS_64 / Principal restrito)
# ---------------------------------------------------------
resource "aws_kms_key" "logs_key" {
  description             = "Chave KMS para criptografia de logs no LocalStack"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable Root Account Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs Service"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = var.environment
  }
}

# ---------------------------------------------------------
# CloudWatch Log Group com Criptografia e Retenção de 1 Ano (CKV_AWS_338)
# ---------------------------------------------------------
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/app/${var.environment}-api"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs_key.arn

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ---------------------------------------------------------
# Security Group Restrito (CKV_AWS_382 e CKV2_AWS_5)
# ---------------------------------------------------------
resource "aws_security_group" "app_sg" {
  name        = "${var.environment}-app-sg"
  description = "Acesso seguro para a aplicacao"
  vpc_id      = aws_vpc.main.id

  #checkov:skip=CKV2_AWS_5:SG pronto para acoplamento dinamico no deploy

  ingress {
    description = "Acesso HTTP restrito a rede interna"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "Saida segura HTTPS para integracoes externas"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
  }
}