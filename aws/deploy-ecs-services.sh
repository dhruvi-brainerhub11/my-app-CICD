#!/bin/bash

###############################################################################
# AWS ECS Deployment Script
# This script registers task definitions and creates/updates ECS services
#
# Prerequisites:
# - Infrastructure must be set up (VPC, ALB, RDS, ECS Cluster)
# - ECR repositories must exist
# - Docker images must be pushed to ECR
#
# Usage: ./deploy-ecs-services.sh [backend-image-uri] [frontend-image-uri]
# Example: ./deploy-ecs-services.sh 619576923139.dkr.ecr.ap-south-1.amazonaws.com/user-app-backend:v1.0 619576923139.dkr.ecr.ap-south-1.amazonaws.com/user-app-frontend:v1.0
###############################################################################

set -e

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

AWS_REGION="ap-south-1"
PROJECT_NAME="user-app"
ECS_CLUSTER_NAME="${PROJECT_NAME}-cluster"
BACKEND_TASK_FAMILY="${PROJECT_NAME}-backend"
FRONTEND_TASK_FAMILY="${PROJECT_NAME}-frontend"
BACKEND_SERVICE_NAME="${PROJECT_NAME}-backend-service"
FRONTEND_SERVICE_NAME="${PROJECT_NAME}-frontend-service"

# Database Configuration
DB_HOST="${1:-myappdb.c9oq2ky8kisq.ap-south-1.rds.amazonaws.com}"
DB_USER="admin"
DB_PASSWORD="Admin123456"
DB_NAME="myappdb"

# Get values from config file if it exists
if [ -f "aws-infrastructure-config.json" ]; then
    ALB_DNS=$(jq -r '.load_balancer.dns' aws-infrastructure-config.json)
    BACKEND_TG_ARN=$(jq -r '.target_groups.backend' aws-infrastructure-config.json)
    FRONTEND_TG_ARN=$(jq -r '.target_groups.frontend' aws-infrastructure-config.json)
    BACKEND_ECR=$(jq -r '.ecr.backend' aws-infrastructure-config.json)
    FRONTEND_ECR=$(jq -r '.ecr.frontend' aws-infrastructure-config.json)
    ECS_TASK_EXECUTION_ROLE=$(jq -r '.iam.task_execution_role' aws-infrastructure-config.json)
    ECS_TASK_ROLE=$(jq -r '.iam.task_role' aws-infrastructure-config.json)
fi

# Use command line arguments if provided
BACKEND_IMAGE="${2:-${BACKEND_ECR}:latest}"
FRONTEND_IMAGE="${3:-${FRONTEND_ECR}:latest}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# ═══════════════════════════════════════════════════════════════════════════
# REGISTER TASK DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════

register_backend_task_definition() {
    log_info "Registering Backend Task Definition"
    
    cat > /tmp/backend-task-def.json << EOF
{
  "family": "$BACKEND_TASK_FAMILY",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "2048",
  "executionRoleArn": "$ECS_TASK_EXECUTION_ROLE",
  "taskRoleArn": "$ECS_TASK_ROLE",
  "containerDefinitions": [
    {
      "name": "$PROJECT_NAME-backend",
      "image": "$BACKEND_IMAGE",
      "essential": true,
      "environment": [
        { "name": "DB_NAME", "value": "$DB_NAME" },
        { "name": "DB_HOST", "value": "$DB_HOST" },
        { "name": "DB_PORT", "value": "3306" },
        { "name": "DB_USER", "value": "$DB_USER" },
        { "name": "DB_PASSWORD", "value": "$DB_PASSWORD" },
        { "name": "PORT", "value": "5000" },
        { "name": "NODE_ENV", "value": "production" },
        { "name": "CORS_ORIGIN", "value": "http://$ALB_DNS" }
      ],
      "portMappings": [
        {
          "containerPort": 5000,
          "hostPort": 5000,
          "protocol": "tcp"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/${PROJECT_NAME}-backend",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "backend"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:5000/api/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

    BACKEND_TASK_REVISION=$(aws ecs register-task-definition \
        --cli-input-json file:///tmp/backend-task-def.json \
        --region "$AWS_REGION" \
        --query 'taskDefinition.revision' \
        --output text)
    
    log_success "Backend Task Definition registered: $BACKEND_TASK_FAMILY:$BACKEND_TASK_REVISION"
}

register_frontend_task_definition() {
    log_info "Registering Frontend Task Definition"
    
    cat > /tmp/frontend-task-def.json << EOF
{
  "family": "$FRONTEND_TASK_FAMILY",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "$ECS_TASK_EXECUTION_ROLE",
  "taskRoleArn": "$ECS_TASK_ROLE",
  "containerDefinitions": [
    {
      "name": "$PROJECT_NAME-frontend",
      "image": "$FRONTEND_IMAGE",
      "essential": true,
      "environment": [
        { "name": "REACT_APP_API_URL", "value": "http://$ALB_DNS" }
      ],
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80,
          "protocol": "tcp"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/${PROJECT_NAME}-frontend",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "frontend"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost/ || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

    FRONTEND_TASK_REVISION=$(aws ecs register-task-definition \
        --cli-input-json file:///tmp/frontend-task-def.json \
        --region "$AWS_REGION" \
        --query 'taskDefinition.revision' \
        --output text)
    
    log_success "Frontend Task Definition registered: $FRONTEND_TASK_FAMILY:$FRONTEND_TASK_REVISION"
}

# ═══════════════════════════════════════════════════════════════════════════
# CREATE/UPDATE ECS SERVICES
# ═══════════════════════════════════════════════════════════════════════════

create_backend_service() {
    log_info "Creating/Updating Backend Service"
    
    # Check if service exists
    if aws ecs describe-services \
        --cluster "$ECS_CLUSTER_NAME" \
        --services "$BACKEND_SERVICE_NAME" \
        --region "$AWS_REGION" 2>/dev/null | grep -q "\"status\": \"ACTIVE\""; then
        
        log_info "Backend service exists, updating..."
        
        aws ecs update-service \
            --cluster "$ECS_CLUSTER_NAME" \
            --service "$BACKEND_SERVICE_NAME" \
            --task-definition "$BACKEND_TASK_FAMILY:$BACKEND_TASK_REVISION" \
            --force-new-deployment \
            --region "$AWS_REGION" > /dev/null
        
        log_success "Backend service updated"
    else
        log_info "Creating new Backend service..."
        
        # Get VPC and subnets from config
        VPC_ID=$(jq -r '.vpc.id' aws-infrastructure-config.json 2>/dev/null || echo "")
        PRIVATE_SUBNET_1=$(jq -r '.subnets.private_1.id' aws-infrastructure-config.json 2>/dev/null || echo "")
        PRIVATE_SUBNET_2=$(jq -r '.subnets.private_2.id' aws-infrastructure-config.json 2>/dev/null || echo "")
        ECS_SG=$(jq -r '.security_groups.ecs' aws-infrastructure-config.json 2>/dev/null || echo "")
        
        aws ecs create-service \
            --cluster "$ECS_CLUSTER_NAME" \
            --service-name "$BACKEND_SERVICE_NAME" \
            --task-definition "$BACKEND_TASK_FAMILY:$BACKEND_TASK_REVISION" \
            --desired-count 2 \
            --launch-type FARGATE \
            --platform-version LATEST \
            --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
            --load-balancers "targetGroupArn=$BACKEND_TG_ARN,containerName=$PROJECT_NAME-backend,containerPort=5000" \
            --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
            --enable-ecs-managed-tags \
            --tags "key=Name,value=$BACKEND_SERVICE_NAME" "key=Environment,value=production" \
            --region "$AWS_REGION" > /dev/null
        
        log_success "Backend service created"
    fi
}

create_frontend_service() {
    log_info "Creating/Updating Frontend Service"
    
    # Check if service exists
    if aws ecs describe-services \
        --cluster "$ECS_CLUSTER_NAME" \
        --services "$FRONTEND_SERVICE_NAME" \
        --region "$AWS_REGION" 2>/dev/null | grep -q "\"status\": \"ACTIVE\""; then
        
        log_info "Frontend service exists, updating..."
        
        aws ecs update-service \
            --cluster "$ECS_CLUSTER_NAME" \
            --service "$FRONTEND_SERVICE_NAME" \
            --task-definition "$FRONTEND_TASK_FAMILY:$FRONTEND_TASK_REVISION" \
            --force-new-deployment \
            --region "$AWS_REGION" > /dev/null
        
        log_success "Frontend service updated"
    else
        log_info "Creating new Frontend service..."
        
        # Get VPC and subnets from config
        VPC_ID=$(jq -r '.vpc.id' aws-infrastructure-config.json 2>/dev/null || echo "")
        PRIVATE_SUBNET_1=$(jq -r '.subnets.private_1.id' aws-infrastructure-config.json 2>/dev/null || echo "")
        PRIVATE_SUBNET_2=$(jq -r '.subnets.private_2.id' aws-infrastructure-config.json 2>/dev/null || echo "")
        ECS_SG=$(jq -r '.security_groups.ecs' aws-infrastructure-config.json 2>/dev/null || echo "")
        
        aws ecs create-service \
            --cluster "$ECS_CLUSTER_NAME" \
            --service-name "$FRONTEND_SERVICE_NAME" \
            --task-definition "$FRONTEND_TASK_FAMILY:$FRONTEND_TASK_REVISION" \
            --desired-count 2 \
            --launch-type FARGATE \
            --platform-version LATEST \
            --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
            --load-balancers "targetGroupArn=$FRONTEND_TG_ARN,containerName=$PROJECT_NAME-frontend,containerPort=80" \
            --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
            --enable-ecs-managed-tags \
            --tags "key=Name,value=$FRONTEND_SERVICE_NAME" "key=Environment,value=production" \
            --region "$AWS_REGION" > /dev/null
        
        log_success "Frontend service created"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# MONITOR DEPLOYMENT
# ═══════════════════════════════════════════════════════════════════════════

monitor_service_deployment() {
    local service_name=$1
    local max_wait=600
    local elapsed=0
    
    log_info "Monitoring $service_name deployment..."
    
    while [ $elapsed -lt $max_wait ]; do
        STATUS=$(aws ecs describe-services \
            --cluster "$ECS_CLUSTER_NAME" \
            --services "$service_name" \
            --region "$AWS_REGION" \
            --query 'services[0].deployments[0].status' \
            --output text)
        
        TASK_COUNT=$(aws ecs describe-services \
            --cluster "$ECS_CLUSTER_NAME" \
            --services "$service_name" \
            --region "$AWS_REGION" \
            --query 'services[0].runningCount' \
            --output text)
        
        DESIRED_COUNT=$(aws ecs describe-services \
            --cluster "$ECS_CLUSTER_NAME" \
            --services "$service_name" \
            --region "$AWS_REGION" \
            --query 'services[0].desiredCount' \
            --output text)
        
        echo -e "${BLUE}[WAIT]${NC} $service_name - Deployment: $STATUS | Running: $TASK_COUNT/$DESIRED_COUNT"
        
        if [ "$STATUS" = "PRIMARY" ] && [ "$TASK_COUNT" = "$DESIRED_COUNT" ]; then
            log_success "$service_name deployment complete"
            return 0
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    log_error "Deployment timeout for $service_name"
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  AWS ECS Deployment Script                                     ║"
    echo "║  Region: $AWS_REGION"
    echo "║  Cluster: $ECS_CLUSTER_NAME"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_info "Backend Image: $BACKEND_IMAGE"
    log_info "Frontend Image: $FRONTEND_IMAGE"
    log_info "Database: $DB_HOST"
    log_info "ALB DNS: $ALB_DNS"
    echo ""
    
    # Register task definitions
    register_backend_task_definition
    register_frontend_task_definition
    echo ""
    
    # Create/Update services
    create_backend_service
    create_frontend_service
    echo ""
    
    # Monitor deployment
    monitor_service_deployment "$BACKEND_SERVICE_NAME"
    monitor_service_deployment "$FRONTEND_SERVICE_NAME"
    echo ""
    
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ✅ Deployment Complete!                                       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    log_success "Access your application at: http://$ALB_DNS"
    echo ""
}

# Validate prerequisites
if [ -z "$ECS_TASK_EXECUTION_ROLE" ] || [ "$ECS_TASK_EXECUTION_ROLE" = "null" ]; then
    log_error "Missing configuration. Run setup-complete-infrastructure.sh first."
    exit 1
fi

main
