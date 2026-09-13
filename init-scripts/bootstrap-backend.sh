#!/bin/bash
set -e

echo "Aguardando LocalStack ficar pronto..."

echo "Criando bucket S3 para o tfstate..."
awslocal s3api create-bucket \
  --bucket devsecops-tfstate-local \
  --region us-east-1

echo "Criando tabela DynamoDB para o lock..."
awslocal dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

echo "Bootstrap do backend concluído."