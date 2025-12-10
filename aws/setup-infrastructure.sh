#!/bin/bash

# User App AWS Infrastructure Setup Script
# This script creates all necessary AWS resources for deploying the User App

set -e

# Configuration Variables
AWS_REGION="${AWS_REGION:-us-east-1}"
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_1_CIDR="10.0.1.0/24"
PUBLIC_SUBNET_2_CIDR="10.0.2.0/24"
PRIVATE_SUBNET_1_CIDR="10.0.10.0/24"
PRIVATE_SUBNET_2_CIDR="10.0.11.0/24"
PROJECT_NAME="user-app"
DB_INSTANCE_IDENTIFIER="${PROJECT_NAME}-db"
ECS_CLUSTER_NAME="${PROJECT_NAME}-cluster"

echo "=========================================="
echo "User App AWS Infrastructure Setup"
echo "=========================================="
echo "Region: $AWS_REGION"
echo ""

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
if ! command_exists aws; then
  echo "❌ AWS CLI is not installed. Please install it first."
  exit 1
fi

echo "✅ AWS CLI found"
echo ""

# Verify AWS credentials
if ! aws sts get-caller-identity --region "$AWS_REGION" > /dev/null; then
  echo "❌ AWS credentials not configured properly"
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account ID: $ACCOUNT_ID"
echo ""

# Create VPC
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PROJECT_NAME}-vpc}]" \
  --region "$AWS_REGION" \
  --query 'Vpc.VpcId' \
  --output text)
echo "✅ VPC created: $VPC_ID"

# Enable DNS
aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames \
  --region "$AWS_REGION"

# Create Internet Gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${PROJECT_NAME}-igw}]" \
  --region "$AWS_REGION" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)
echo "✅ Internet Gateway created: $IGW_ID"

# Attach IGW to VPC
aws ec2 attach-internet-gateway \
  --vpc-id "$VPC_ID" \
  --internet-gateway-id "$IGW_ID" \
  --region "$AWS_REGION"

# Create Public Subnets
echo "Creating Public Subnets..."
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$PUBLIC_SUBNET_1_CIDR" \
  --availability-zone "${AWS_REGION}a" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-subnet-1a}]" \
  --region "$AWS_REGION" \
  --query 'Subnet.SubnetId' \
  --output text)
echo "✅ Public Subnet 1: $PUBLIC_SUBNET_1"

PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$PUBLIC_SUBNET_2_CIDR" \
  --availability-zone "${AWS_REGION}b" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-subnet-1b}]" \
  --region "$AWS_REGION" \
  --query 'Subnet.SubnetId' \
  --output text)
echo "✅ Public Subnet 2: $PUBLIC_SUBNET_2"

# Create Private Subnets
echo "Creating Private Subnets..."
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$PRIVATE_SUBNET_1_CIDR" \
  --availability-zone "${AWS_REGION}a" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-subnet-1a}]" \
  --region "$AWS_REGION" \
  --query 'Subnet.SubnetId' \
  --output text)
echo "✅ Private Subnet 1: $PRIVATE_SUBNET_1"

PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$PRIVATE_SUBNET_2_CIDR" \
  --availability-zone "${AWS_REGION}b" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-subnet-1b}]" \
  --region "$AWS_REGION" \
  --query 'Subnet.SubnetId' \
  --output text)
echo "✅ Private Subnet 2: $PRIVATE_SUBNET_2"

# Create Route Tables
echo "Creating Route Tables..."
PUBLIC_RT=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-rt}]" \
  --region "$AWS_REGION" \
  --query 'RouteTable.RouteTableId' \
  --output text)
echo "✅ Public Route Table: $PUBLIC_RT"

PRIVATE_RT=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-rt}]" \
  --region "$AWS_REGION" \
  --query 'RouteTable.RouteTableId' \
  --output text)
echo "✅ Private Route Table: $PRIVATE_RT"

# Add routes
aws ec2 create-route \
  --route-table-id "$PUBLIC_RT" \
  --destination-cidr-block "0.0.0.0/0" \
  --gateway-id "$IGW_ID" \
  --region "$AWS_REGION"

# Associate subnets with route tables
aws ec2 associate-route-table --subnet-id "$PUBLIC_SUBNET_1" --route-table-id "$PUBLIC_RT" --region "$AWS_REGION"
aws ec2 associate-route-table --subnet-id "$PUBLIC_SUBNET_2" --route-table-id "$PUBLIC_RT" --region "$AWS_REGION"
aws ec2 associate-route-table --subnet-id "$PRIVATE_SUBNET_1" --route-table-id "$PRIVATE_RT" --region "$AWS_REGION"
aws ec2 associate-route-table --subnet-id "$PRIVATE_SUBNET_2" --route-table-id "$PRIVATE_RT" --region "$AWS_REGION"

echo ""
echo "✅ VPC and Networking Setup Complete!"
echo ""
echo "VPC Configuration:"
echo "  VPC ID: $VPC_ID"
echo "  IGW ID: $IGW_ID"
echo "  Public Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "  Private Subnets: $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"
echo ""

# Create ECR Repositories
echo "Creating ECR Repositories..."
aws ecr create-repository \
  --repository-name ${PROJECT_NAME}-backend \
  --region "$AWS_REGION" 2>/dev/null || echo "⚠️  Backend ECR repository already exists"

aws ecr create-repository \
  --repository-name ${PROJECT_NAME}-frontend \
  --region "$AWS_REGION" 2>/dev/null || echo "⚠️  Frontend ECR repository already exists"

echo "✅ ECR repositories created/verified"
echo ""

# Create ECS Cluster
echo "Creating ECS Cluster..."
aws ecs create-cluster \
  --cluster-name "$ECS_CLUSTER_NAME" \
  --region "$AWS_REGION" 2>/dev/null || echo "⚠️  ECS cluster already exists"

echo "✅ ECS Cluster created/verified: $ECS_CLUSTER_NAME"
echo ""

# Create CloudWatch Log Groups
echo "Creating CloudWatch Log Groups..."
aws logs create-log-group --log-group-name "/ecs/${PROJECT_NAME}-backend" --region "$AWS_REGION" 2>/dev/null || echo "⚠️  Backend log group already exists"
aws logs create-log-group --log-group-name "/ecs/${PROJECT_NAME}-frontend" --region "$AWS_REGION" 2>/dev/null || echo "⚠️  Frontend log group already exists"

echo "✅ CloudWatch Log Groups created/verified"
echo ""

echo "=========================================="
echo "✅ AWS Infrastructure Setup Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Create RDS MySQL instance (private subnets)"
echo "2. Create Security Groups for ALB, ECS, and RDS"
echo "3. Create Application Load Balancer"
echo "4. Create ECS Task Definitions"
echo "5. Create ECS Services"
echo "6. Configure GitHub Secrets"
echo "7. Push code to GitHub to trigger CI/CD"
echo ""
echo "Configuration Summary:"
echo "  AWS Region: $AWS_REGION"
echo "  Account ID: $ACCOUNT_ID"
echo "  VPC ID: $VPC_ID"
echo "  ECS Cluster: $ECS_CLUSTER_NAME"
echo ""
