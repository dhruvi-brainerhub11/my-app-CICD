#!/bin/bash

###############################################################################
# AWS ECS Complete Infrastructure Setup Script
# This script automates the creation of:
# - VPC with Public & Private Subnets
# - NAT Gateway for private subnet
# - ALB (Application Load Balancer)
# - Target Groups
# - RDS MySQL Database
# - ECS Cluster
# - CloudWatch Log Groups
# - Security Groups
# - IAM Roles and Policies
#
# Usage: ./setup-complete-infrastructure.sh
###############################################################################

set -e  # Exit on error

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION VARIABLES
# ═══════════════════════════════════════════════════════════════════════════

# AWS Configuration
AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PROJECT_NAME="user-app"

# VPC Configuration
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_1_CIDR="10.0.1.0/24"      # AZ ap-south-1a
PUBLIC_SUBNET_2_CIDR="10.0.2.0/24"      # AZ ap-south-1b
PRIVATE_SUBNET_1_CIDR="10.0.10.0/24"    # AZ ap-south-1a
PRIVATE_SUBNET_2_CIDR="10.0.11.0/24"    # AZ ap-south-1b

# RDS Configuration
DB_NAME="myappdb"
DB_USER="admin"
DB_PASSWORD="Admin123456"
DB_INSTANCE_CLASS="db.t3.micro"

# ECS Configuration
ECS_CLUSTER_NAME="${PROJECT_NAME}-cluster"
BACKEND_SERVICE_NAME="${PROJECT_NAME}-backend-service"
FRONTEND_SERVICE_NAME="${PROJECT_NAME}-frontend-service"
BACKEND_TASK_FAMILY="${PROJECT_NAME}-backend"
FRONTEND_TASK_FAMILY="${PROJECT_NAME}-frontend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ═══════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

wait_for_resource() {
    local resource_type=$1
    local resource_id=$2
    local max_attempts=60
    local attempt=0

    log_info "Waiting for $resource_type: $resource_id"
    while [ $attempt -lt $max_attempts ]; do
        if aws ec2 describe-$resource_type --$resource_type-ids "$resource_id" --region "$AWS_REGION" &>/dev/null; then
            log_success "$resource_type is ready"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    log_error "Timeout waiting for $resource_type: $resource_id"
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 1: CREATE VPC AND SUBNETS
# ═══════════════════════════════════════════════════════════════════════════

create_vpc() {
    log_info "Creating VPC with CIDR: $VPC_CIDR"
    
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block "$VPC_CIDR" \
        --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PROJECT_NAME}-vpc},{Key=Environment,Value=production}]" \
        --region "$AWS_REGION" \
        --query 'Vpc.VpcId' \
        --output text)
    
    log_success "VPC created: $VPC_ID"
    
    # Enable DNS hostnames
    aws ec2 modify-vpc-attribute \
        --vpc-id "$VPC_ID" \
        --enable-dns-hostnames \
        --region "$AWS_REGION"
    
    # Enable DNS support
    aws ec2 modify-vpc-attribute \
        --vpc-id "$VPC_ID" \
        --enable-dns-support \
        --region "$AWS_REGION"
    
    log_success "DNS enabled for VPC"
}

create_subnets() {
    log_info "Creating Public Subnets"
    
    # Public Subnet 1 (ap-south-1a)
    PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block "$PUBLIC_SUBNET_1_CIDR" \
        --availability-zone "${AWS_REGION}a" \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-subnet-1a}]" \
        --region "$AWS_REGION" \
        --query 'Subnet.SubnetId' \
        --output text)
    
    log_success "Public Subnet 1 created: $PUBLIC_SUBNET_1"
    
    # Public Subnet 2 (ap-south-1b)
    PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block "$PUBLIC_SUBNET_2_CIDR" \
        --availability-zone "${AWS_REGION}b" \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-subnet-1b}]" \
        --region "$AWS_REGION" \
        --query 'Subnet.SubnetId' \
        --output text)
    
    log_success "Public Subnet 2 created: $PUBLIC_SUBNET_2"
    
    log_info "Creating Private Subnets"
    
    # Private Subnet 1 (ap-south-1a)
    PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block "$PRIVATE_SUBNET_1_CIDR" \
        --availability-zone "${AWS_REGION}a" \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-subnet-1a}]" \
        --region "$AWS_REGION" \
        --query 'Subnet.SubnetId' \
        --output text)
    
    log_success "Private Subnet 1 created: $PRIVATE_SUBNET_1"
    
    # Private Subnet 2 (ap-south-1b)
    PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block "$PRIVATE_SUBNET_2_CIDR" \
        --availability-zone "${AWS_REGION}b" \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-subnet-1b}]" \
        --region "$AWS_REGION" \
        --query 'Subnet.SubnetId' \
        --output text)
    
    log_success "Private Subnet 2 created: $PRIVATE_SUBNET_2"
    
    # Enable auto-assign public IP for public subnets
    aws ec2 modify-subnet-attribute \
        --subnet-id "$PUBLIC_SUBNET_1" \
        --map-public-ip-on-launch \
        --region "$AWS_REGION"
    
    aws ec2 modify-subnet-attribute \
        --subnet-id "$PUBLIC_SUBNET_2" \
        --map-public-ip-on-launch \
        --region "$AWS_REGION"
    
    log_success "Auto-assign public IP enabled for public subnets"
}

create_internet_gateway() {
    log_info "Creating Internet Gateway"
    
    IGW_ID=$(aws ec2 create-internet-gateway \
        --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${PROJECT_NAME}-igw}]" \
        --region "$AWS_REGION" \
        --query 'InternetGateway.InternetGatewayId' \
        --output text)
    
    log_success "Internet Gateway created: $IGW_ID"
    
    # Attach IGW to VPC
    aws ec2 attach-internet-gateway \
        --internet-gateway-id "$IGW_ID" \
        --vpc-id "$VPC_ID" \
        --region "$AWS_REGION"
    
    log_success "Internet Gateway attached to VPC"
}

create_route_tables() {
    log_info "Creating Route Tables"
    
    # Public Route Table
    PUBLIC_RT=$(aws ec2 create-route-table \
        --vpc-id "$VPC_ID" \
        --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-rt}]" \
        --region "$AWS_REGION" \
        --query 'RouteTable.RouteTableId' \
        --output text)
    
    log_success "Public Route Table created: $PUBLIC_RT"
    
    # Add route to IGW
    aws ec2 create-route \
        --route-table-id "$PUBLIC_RT" \
        --destination-cidr-block "0.0.0.0/0" \
        --gateway-id "$IGW_ID" \
        --region "$AWS_REGION"
    
    log_success "Route to IGW added"
    
    # Associate public subnets with public route table
    aws ec2 associate-route-table \
        --subnet-id "$PUBLIC_SUBNET_1" \
        --route-table-id "$PUBLIC_RT" \
        --region "$AWS_REGION" > /dev/null
    
    aws ec2 associate-route-table \
        --subnet-id "$PUBLIC_SUBNET_2" \
        --route-table-id "$PUBLIC_RT" \
        --region "$AWS_REGION" > /dev/null
    
    log_success "Public subnets associated with public route table"
    
    # Private Route Table
    PRIVATE_RT=$(aws ec2 create-route-table \
        --vpc-id "$VPC_ID" \
        --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-rt}]" \
        --region "$AWS_REGION" \
        --query 'RouteTable.RouteTableId' \
        --output text)
    
    log_success "Private Route Table created: $PRIVATE_RT"
    
    # Associate private subnets with private route table
    aws ec2 associate-route-table \
        --subnet-id "$PRIVATE_SUBNET_1" \
        --route-table-id "$PRIVATE_RT" \
        --region "$AWS_REGION" > /dev/null
    
    aws ec2 associate-route-table \
        --subnet-id "$PRIVATE_SUBNET_2" \
        --route-table-id "$PRIVATE_RT" \
        --region "$AWS_REGION" > /dev/null
    
    log_success "Private subnets associated with private route table"
}

create_nat_gateway() {
    log_info "Creating NAT Gateway for private subnets"
    
    # Allocate Elastic IP
    EIP=$(aws ec2 allocate-address \
        --domain vpc \
        --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${PROJECT_NAME}-nat-eip}]" \
        --region "$AWS_REGION" \
        --query 'AllocationId' \
        --output text)
    
    log_success "Elastic IP allocated: $EIP"
    
    # Create NAT Gateway in public subnet
    NAT_GATEWAY_ID=$(aws ec2 create-nat-gateway \
        --subnet-id "$PUBLIC_SUBNET_1" \
        --allocation-id "$EIP" \
        --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=${PROJECT_NAME}-nat}]" \
        --region "$AWS_REGION" \
        --query 'NatGateway.NatGatewayId' \
        --output text)
    
    log_success "NAT Gateway created: $NAT_GATEWAY_ID"
    
    # Wait for NAT Gateway to be available
    log_info "Waiting for NAT Gateway to be available..."
    aws ec2 wait nat-gateway-available \
        --nat-gateway-ids "$NAT_GATEWAY_ID" \
        --region "$AWS_REGION"
    
    log_success "NAT Gateway is available"
    
    # Add route to private route table
    aws ec2 create-route \
        --route-table-id "$PRIVATE_RT" \
        --destination-cidr-block "0.0.0.0/0" \
        --nat-gateway-id "$NAT_GATEWAY_ID" \
        --region "$AWS_REGION"
    
    log_success "Route to NAT Gateway added to private route table"
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 2: CREATE SECURITY GROUPS
# ═══════════════════════════════════════════════════════════════════════════

create_security_groups() {
    log_info "Creating Security Groups"
    
    # ALB Security Group
    ALB_SG=$(aws ec2 create-security-group \
        --group-name "${PROJECT_NAME}-alb-sg" \
        --description "Security group for ALB" \
        --vpc-id "$VPC_ID" \
        --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${PROJECT_NAME}-alb-sg}]" \
        --region "$AWS_REGION" \
        --query 'GroupId' \
        --output text)
    
    log_success "ALB Security Group created: $ALB_SG"
    
    # Allow HTTP to ALB
    aws ec2 authorize-security-group-ingress \
        --group-id "$ALB_SG" \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    # Allow HTTPS to ALB
    aws ec2 authorize-security-group-ingress \
        --group-id "$ALB_SG" \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    log_success "Inbound rules added to ALB SG (HTTP, HTTPS)"
    
    # ECS Tasks Security Group
    ECS_SG=$(aws ec2 create-security-group \
        --group-name "${PROJECT_NAME}-ecs-sg" \
        --description "Security group for ECS tasks" \
        --vpc-id "$VPC_ID" \
        --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${PROJECT_NAME}-ecs-sg}]" \
        --region "$AWS_REGION" \
        --query 'GroupId' \
        --output text)
    
    log_success "ECS Security Group created: $ECS_SG"
    
    # Allow traffic from ALB to ECS
    aws ec2 authorize-security-group-ingress \
        --group-id "$ECS_SG" \
        --protocol tcp \
        --port 0-65535 \
        --source-group "$ALB_SG" \
        --region "$AWS_REGION"
    
    # Allow ECS to communicate with itself
    aws ec2 authorize-security-group-ingress \
        --group-id "$ECS_SG" \
        --protocol tcp \
        --port 0-65535 \
        --source-group "$ECS_SG" \
        --region "$AWS_REGION"
    
    log_success "Inbound rules added to ECS SG"
    
    # RDS Security Group
    RDS_SG=$(aws ec2 create-security-group \
        --group-name "${PROJECT_NAME}-rds-sg" \
        --description "Security group for RDS" \
        --vpc-id "$VPC_ID" \
        --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${PROJECT_NAME}-rds-sg}]" \
        --region "$AWS_REGION" \
        --query 'GroupId' \
        --output text)
    
    log_success "RDS Security Group created: $RDS_SG"
    
    # Allow MySQL from ECS
    aws ec2 authorize-security-group-ingress \
        --group-id "$RDS_SG" \
        --protocol tcp \
        --port 3306 \
        --source-group "$ECS_SG" \
        --region "$AWS_REGION"
    
    log_success "MySQL access from ECS allowed"
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 3: CREATE APPLICATION LOAD BALANCER
# ═══════════════════════════════════════════════════════════════════════════

create_alb() {
    log_info "Creating Application Load Balancer"
    
    ALB_ARN=$(aws elbv2 create-load-balancer \
        --name "${PROJECT_NAME}-alb" \
        --subnets "$PUBLIC_SUBNET_1" "$PUBLIC_SUBNET_2" \
        --security-groups "$ALB_SG" \
        --scheme internet-facing \
        --type application \
        --ip-address-type ipv4 \
        --tags "Key=Name,Value=${PROJECT_NAME}-alb" \
        --region "$AWS_REGION" \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text)
    
    log_success "ALB created: $ALB_ARN"
    
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns "$ALB_ARN" \
        --region "$AWS_REGION" \
        --query 'LoadBalancers[0].DNSName' \
        --output text)
    
    log_success "ALB DNS: $ALB_DNS"
}

create_target_groups() {
    log_info "Creating Target Groups"
    
    # Backend Target Group
    BACKEND_TG_ARN=$(aws elbv2 create-target-group \
        --name "${PROJECT_NAME}-backend-tg" \
        --protocol HTTP \
        --port 5000 \
        --vpc-id "$VPC_ID" \
        --target-type ip \
        --health-check-enabled \
        --health-check-protocol HTTP \
        --health-check-path "/api/health" \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 5 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 3 \
        --matcher "HttpCode=200" \
        --tags "Key=Name,Value=${PROJECT_NAME}-backend-tg" \
        --region "$AWS_REGION" \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text)
    
    log_success "Backend Target Group created: $BACKEND_TG_ARN"
    
    # Frontend Target Group
    FRONTEND_TG_ARN=$(aws elbv2 create-target-group \
        --name "${PROJECT_NAME}-frontend-tg" \
        --protocol HTTP \
        --port 80 \
        --vpc-id "$VPC_ID" \
        --target-type ip \
        --health-check-enabled \
        --health-check-protocol HTTP \
        --health-check-path "/" \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 5 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 3 \
        --matcher "HttpCode=200" \
        --tags "Key=Name,Value=${PROJECT_NAME}-frontend-tg" \
        --region "$AWS_REGION" \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text)
    
    log_success "Frontend Target Group created: $FRONTEND_TG_ARN"
}

create_alb_listeners() {
    log_info "Creating ALB Listeners"
    
    # Get ALB ARN from describe call
    ALB_ARN=$(aws elbv2 describe-load-balancers \
        --query "LoadBalancers[?LoadBalancerName=='${PROJECT_NAME}-alb'].LoadBalancerArn" \
        --region "$AWS_REGION" \
        --output text)
    
    # Default listener - route to frontend
    aws elbv2 create-listener \
        --load-balancer-arn "$ALB_ARN" \
        --protocol HTTP \
        --port 80 \
        --default-actions "Type=forward,TargetGroupArn=$FRONTEND_TG_ARN" \
        --region "$AWS_REGION" > /dev/null
    
    log_success "Default listener created (routes to frontend)"
    
    # Get listener ARN
    LISTENER_ARN=$(aws elbv2 describe-listeners \
        --load-balancer-arn "$ALB_ARN" \
        --region "$AWS_REGION" \
        --query 'Listeners[0].ListenerArn' \
        --output text)
    
    # Create rule for /api/* -> backend
    aws elbv2 create-rule \
        --listener-arn "$LISTENER_ARN" \
        --conditions Field=path-pattern,Values=/api/* \
        --priority 1 \
        --actions Type=forward,TargetGroupArn="$BACKEND_TG_ARN" \
        --region "$AWS_REGION" > /dev/null
    
    log_success "Rule created: /api/* routes to backend target group"
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 4: CREATE RDS DATABASE
# ═══════════════════════════════════════════════════════════════════════════

create_db_subnet_group() {
    log_info "Creating DB Subnet Group"
    
    aws rds create-db-subnet-group \
        --db-subnet-group-name "${PROJECT_NAME}-db-subnet-group" \
        --db-subnet-group-description "Subnet group for RDS" \
        --subnet-ids "$PRIVATE_SUBNET_1" "$PRIVATE_SUBNET_2" \
        --tags "Key=Name,Value=${PROJECT_NAME}-db-subnet-group" \
        --region "$AWS_REGION" > /dev/null
    
    log_success "DB Subnet Group created"
}

create_rds_database() {
    log_info "Creating RDS MySQL Database"
    
    RDS_ENDPOINT=$(aws rds create-db-instance \
        --db-instance-identifier "${PROJECT_NAME}-db" \
        --db-instance-class "$DB_INSTANCE_CLASS" \
        --engine mysql \
        --engine-version "8.0.35" \
        --master-username "$DB_USER" \
        --master-user-password "$DB_PASSWORD" \
        --allocated-storage 20 \
        --db-name "$DB_NAME" \
        --vpc-security-group-ids "$RDS_SG" \
        --db-subnet-group-name "${PROJECT_NAME}-db-subnet-group" \
        --multi-az false \
        --publicly-accessible false \
        --storage-type gp2 \
        --tags "Key=Name,Value=${PROJECT_NAME}-db" "Key=Environment,Value=production" \
        --region "$AWS_REGION" \
        --query 'DBInstance.DBInstanceIdentifier' \
        --output text)
    
    log_success "RDS instance created: $RDS_ENDPOINT"
    log_info "Waiting for RDS instance to be available (this may take 5-10 minutes)..."
    
    aws rds wait db-instance-available \
        --db-instance-identifier "${PROJECT_NAME}-db" \
        --region "$AWS_REGION"
    
    RDS_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier "${PROJECT_NAME}-db" \
        --region "$AWS_REGION" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text)
    
    log_success "RDS instance is available at: $RDS_ENDPOINT"
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 5: CREATE ECS CLUSTER
# ═══════════════════════════════════════════════════════════════════════════

create_ecs_cluster() {
    log_info "Creating ECS Cluster"
    
    aws ecs create-cluster \
        --cluster-name "$ECS_CLUSTER_NAME" \
        --capacity-providers FARGATE FARGATE_SPOT \
        --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1,base=1 \
        --tags "key=Name,value=${PROJECT_NAME}-cluster" "key=Environment,value=production" \
        --region "$AWS_REGION" > /dev/null
    
    log_success "ECS Cluster created: $ECS_CLUSTER_NAME"
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 6: CREATE CLOUDWATCH LOG GROUPS
# ═══════════════════════════════════════════════════════════════════════════

create_log_groups() {
    log_info "Creating CloudWatch Log Groups"
    
    # Backend log group
    aws logs create-log-group \
        --log-group-name "/ecs/${PROJECT_NAME}-backend" \
        --region "$AWS_REGION" 2>/dev/null || true
    
    aws logs put-retention-policy \
        --log-group-name "/ecs/${PROJECT_NAME}-backend" \
        --retention-in-days 7 \
        --region "$AWS_REGION"
    
    log_success "Backend log group created: /ecs/${PROJECT_NAME}-backend"
    
    # Frontend log group
    aws logs create-log-group \
        --log-group-name "/ecs/${PROJECT_NAME}-frontend" \
        --region "$AWS_REGION" 2>/dev/null || true
    
    aws logs put-retention-policy \
        --log-group-name "/ecs/${PROJECT_NAME}-frontend" \
        --retention-in-days 7 \
        --region "$AWS_REGION"
    
    log_success "Frontend log group created: /ecs/${PROJECT_NAME}-frontend"
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 7: CREATE ECR REPOSITORIES
# ═══════════════════════════════════════════════════════════════════════════

create_ecr_repositories() {
    log_info "Creating ECR Repositories"
    
    # Backend ECR
    BACKEND_ECR=$(aws ecr create-repository \
        --repository-name "${PROJECT_NAME}-backend" \
        --region "$AWS_REGION" \
        --query 'repository.repositoryUri' \
        --output text 2>/dev/null) || \
    BACKEND_ECR=$(aws ecr describe-repositories \
        --repository-names "${PROJECT_NAME}-backend" \
        --region "$AWS_REGION" \
        --query 'repositories[0].repositoryUri' \
        --output text)
    
    log_success "Backend ECR repository: $BACKEND_ECR"
    
    # Frontend ECR
    FRONTEND_ECR=$(aws ecr create-repository \
        --repository-name "${PROJECT_NAME}-frontend" \
        --region "$AWS_REGION" \
        --query 'repository.repositoryUri' \
        --output text 2>/dev/null) || \
    FRONTEND_ECR=$(aws ecr describe-repositories \
        --repository-names "${PROJECT_NAME}-frontend" \
        --region "$AWS_REGION" \
        --query 'repositories[0].repositoryUri' \
        --output text)
    
    log_success "Frontend ECR repository: $FRONTEND_ECR"
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 8: CREATE IAM ROLES
# ═══════════════════════════════════════════════════════════════════════════

create_iam_roles() {
    log_info "Creating IAM Roles for ECS"
    
    # Create trust policy for ECS tasks
    cat > /tmp/ecs-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # Create ECS Task Execution Role
    ECS_TASK_EXECUTION_ROLE=$(aws iam create-role \
        --role-name "${PROJECT_NAME}-ecs-task-execution-role" \
        --assume-role-policy-document file:///tmp/ecs-trust-policy.json \
        --query 'Role.Arn' \
        --output text 2>/dev/null) || \
    ECS_TASK_EXECUTION_ROLE=$(aws iam get-role \
        --role-name "${PROJECT_NAME}-ecs-task-execution-role" \
        --query 'Role.Arn' \
        --output text)
    
    log_success "ECS Task Execution Role created: $ECS_TASK_EXECUTION_ROLE"
    
    # Attach policy to execution role
    aws iam attach-role-policy \
        --role-name "${PROJECT_NAME}-ecs-task-execution-role" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" 2>/dev/null || true
    
    # Create policy for CloudWatch logs
    cat > /tmp/ecs-logs-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF

    aws iam put-role-policy \
        --role-name "${PROJECT_NAME}-ecs-task-execution-role" \
        --policy-name "ECSLogsPolicy" \
        --policy-document file:///tmp/ecs-logs-policy.json 2>/dev/null || true
    
    log_success "CloudWatch logs policy attached"
    
    # Create ECS Task Role
    ECS_TASK_ROLE=$(aws iam create-role \
        --role-name "${PROJECT_NAME}-ecs-task-role" \
        --assume-role-policy-document file:///tmp/ecs-trust-policy.json \
        --query 'Role.Arn' \
        --output text 2>/dev/null) || \
    ECS_TASK_ROLE=$(aws iam get-role \
        --role-name "${PROJECT_NAME}-ecs-task-role" \
        --query 'Role.Arn' \
        --output text)
    
    log_success "ECS Task Role created: $ECS_TASK_ROLE"
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  AWS ECS Complete Infrastructure Setup                          ║"
    echo "║  Project: $PROJECT_NAME"
    echo "║  Region: $AWS_REGION"
    echo "║  Account ID: $AWS_ACCOUNT_ID"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_info "Starting infrastructure setup..."
    echo ""
    
    # Step 1: VPC and Networking
    log_info "=== STEP 1: Creating VPC and Networking ==="
    create_vpc
    create_subnets
    create_internet_gateway
    create_route_tables
    create_nat_gateway
    echo ""
    
    # Step 2: Security Groups
    log_info "=== STEP 2: Creating Security Groups ==="
    create_security_groups
    echo ""
    
    # Step 3: Load Balancer
    log_info "=== STEP 3: Creating Application Load Balancer ==="
    create_alb
    create_target_groups
    create_alb_listeners
    echo ""
    
    # Step 4: RDS Database
    log_info "=== STEP 4: Creating RDS Database ==="
    create_db_subnet_group
    create_rds_database
    echo ""
    
    # Step 5: ECS Cluster
    log_info "=== STEP 5: Creating ECS Cluster ==="
    create_ecs_cluster
    echo ""
    
    # Step 6: CloudWatch Logs
    log_info "=== STEP 6: Creating CloudWatch Log Groups ==="
    create_log_groups
    echo ""
    
    # Step 7: ECR Repositories
    log_info "=== STEP 7: Creating ECR Repositories ==="
    create_ecr_repositories
    echo ""
    
    # Step 8: IAM Roles
    log_info "=== STEP 8: Creating IAM Roles ==="
    create_iam_roles
    echo ""
    
    # Save configuration to file
    save_configuration
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ✅ Infrastructure Setup Complete!                             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

save_configuration() {
    log_info "Saving configuration to aws-infrastructure-config.json"
    
    cat > aws-infrastructure-config.json << EOF
{
  "project_name": "$PROJECT_NAME",
  "aws_region": "$AWS_REGION",
  "aws_account_id": "$AWS_ACCOUNT_ID",
  
  "vpc": {
    "id": "$VPC_ID",
    "cidr": "$VPC_CIDR"
  },
  
  "subnets": {
    "public_1": {
      "id": "$PUBLIC_SUBNET_1",
      "cidr": "$PUBLIC_SUBNET_1_CIDR",
      "az": "${AWS_REGION}a"
    },
    "public_2": {
      "id": "$PUBLIC_SUBNET_2",
      "cidr": "$PUBLIC_SUBNET_2_CIDR",
      "az": "${AWS_REGION}b"
    },
    "private_1": {
      "id": "$PRIVATE_SUBNET_1",
      "cidr": "$PRIVATE_SUBNET_1_CIDR",
      "az": "${AWS_REGION}a"
    },
    "private_2": {
      "id": "$PRIVATE_SUBNET_2",
      "cidr": "$PRIVATE_SUBNET_2_CIDR",
      "az": "${AWS_REGION}b"
    }
  },
  
  "security_groups": {
    "alb": "$ALB_SG",
    "ecs": "$ECS_SG",
    "rds": "$RDS_SG"
  },
  
  "load_balancer": {
    "arn": "$ALB_ARN",
    "dns": "$ALB_DNS"
  },
  
  "target_groups": {
    "backend": "$BACKEND_TG_ARN",
    "frontend": "$FRONTEND_TG_ARN"
  },
  
  "rds": {
    "endpoint": "$RDS_ENDPOINT",
    "db_name": "$DB_NAME",
    "db_user": "$DB_USER",
    "port": 3306
  },
  
  "ecs": {
    "cluster_name": "$ECS_CLUSTER_NAME"
  },
  
  "ecr": {
    "backend": "$BACKEND_ECR",
    "frontend": "$FRONTEND_ECR"
  },
  
  "iam": {
    "task_execution_role": "$ECS_TASK_EXECUTION_ROLE",
    "task_role": "$ECS_TASK_ROLE"
  }
}
EOF

    log_success "Configuration saved to aws-infrastructure-config.json"
    cat aws-infrastructure-config.json
}

# Run main function
main

