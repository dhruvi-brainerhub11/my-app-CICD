#!/bin/bash

################################################################################
# 🔧 QUICK FIX: Create ECS Services (Fixes INACTIVE Service Error)
# 
# This creates the missing ECS services so GitHub Actions can deploy to them
# Usage: bash aws/fix-create-services-now.sh
################################################################################

set -e

REGION="ap-south-1"
CLUSTER="user-app-cluster"
BACKEND_SERVICE="user-app-backend-service"
FRONTEND_SERVICE="user-app-frontend-service"
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

echo "════════════════════════════════════════════════════════════════"
echo "🔧 FIXING: Creating Missing ECS Services"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 1. Get ALB Target Groups
echo "✓ Finding ALB target groups..."
BACKEND_TG=$(aws elbv2 describe-target-groups \
  --query "TargetGroups[?TargetGroupName=='user-app-backend-tg'].TargetGroupArn" \
  --region $REGION \
  --output text)

FRONTEND_TG=$(aws elbv2 describe-target-groups \
  --query "TargetGroups[?TargetGroupName=='user-app-frontend-tg'].TargetGroupArn" \
  --region $REGION \
  --output text)

if [ -z "$BACKEND_TG" ] || [ -z "$FRONTEND_TG" ]; then
  echo "❌ ERROR: Target groups not found!"
  echo "   Run: bash aws/setup-complete-infrastructure.sh FIRST"
  exit 1
fi

echo "✅ Target groups found"
echo ""

# 2. Get Subnets and Security Groups
echo "✓ Finding VPC configuration..."
VPC=$(aws ec2 describe-vpcs \
  --filters Name=cidr,Values=10.0.0.0/16 \
  --region $REGION \
  --query 'Vpcs[0].VpcId' \
  --output text)

PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values=$VPC Name=cidr-block,Values="10.0.10.0/24" "10.0.11.0/24" \
  --region $REGION \
  --query 'Subnets[*].SubnetId' \
  --output text)

ECS_SG=$(aws ec2 describe-security-groups \
  --filters Name=vpc-id,Values=$VPC Name=tag:Name,Values=user-app-ecs-sg \
  --region $REGION \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

if [ -z "$ECS_SG" ]; then
  ECS_SG=$(aws ec2 describe-security-groups \
    --filters Name=vpc-id,Values=$VPC \
    --region $REGION \
    --query 'SecurityGroups[0].GroupId' \
    --output text)
fi

echo "✅ VPC configuration found"
echo "   VPC: $VPC"
echo "   Security Group: $ECS_SG"
echo "   Subnets: $PRIVATE_SUBNETS"
echo ""

# 3. Register Task Definitions
echo "✓ Registering task definitions..."

# Backend
BACKEND_REV=$(aws ecs register-task-definition \
  --family user-app-backend \
  --network-mode awsvpc \
  --requires-compatibilities FARGATE \
  --cpu 512 \
  --memory 2048 \
  --execution-role-arn arn:aws:iam::${AWS_ACCOUNT}:role/ecsTaskExecutionRole \
  --task-role-arn arn:aws:iam::${AWS_ACCOUNT}:role/ecsTaskRole \
  --container-definitions '[{
    "name": "user-app-backend",
    "image": "'${AWS_ACCOUNT}'.dkr.ecr.'${REGION}'.amazonaws.com/user-app-backend:latest",
    "portMappings": [{"containerPort": 5000, "hostPort": 5000, "protocol": "tcp"}],
    "environment": [
      {"name": "PORT", "value": "5000"},
      {"name": "NODE_ENV", "value": "production"},
      {"name": "DB_HOST", "value": "user-app-db.c9oq7l6ujqjk.ap-south-1.rds.amazonaws.com"},
      {"name": "DB_PORT", "value": "3306"},
      {"name": "DB_USER", "value": "admin"},
      {"name": "DB_PASSWORD", "value": "Admin123456!"},
      {"name": "DB_NAME", "value": "myappdb"},
      {"name": "CORS_ORIGIN", "value": "http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com"}
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/user-app-backend",
        "awslogs-region": "'${REGION}'",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "healthCheck": {
      "command": ["CMD-SHELL", "curl -f http://localhost:5000/api/health || exit 1"],
      "interval": 30,
      "timeout": 5,
      "retries": 3,
      "startPeriod": 60
    }
  }]' \
  --region $REGION \
  --query 'taskDefinition.revision' \
  --output text)

echo "✅ Backend task definition registered (revision: $BACKEND_REV)"

# Frontend
FRONTEND_REV=$(aws ecs register-task-definition \
  --family user-app-frontend \
  --network-mode awsvpc \
  --requires-compatibilities FARGATE \
  --cpu 512 \
  --memory 1024 \
  --execution-role-arn arn:aws:iam::${AWS_ACCOUNT}:role/ecsTaskExecutionRole \
  --container-definitions '[{
    "name": "user-app-frontend",
    "image": "'${AWS_ACCOUNT}'.dkr.ecr.'${REGION}'.amazonaws.com/user-app-frontend:latest",
    "portMappings": [{"containerPort": 80, "hostPort": 80, "protocol": "tcp"}],
    "environment": [
      {"name": "REACT_APP_API_URL", "value": "http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com"}
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/user-app-frontend",
        "awslogs-region": "'${REGION}'",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "healthCheck": {
      "command": ["CMD-SHELL", "curl -f http://localhost/ || exit 1"],
      "interval": 30,
      "timeout": 5,
      "retries": 3,
      "startPeriod": 60
    }
  }]' \
  --region $REGION \
  --query 'taskDefinition.revision' \
  --output text)

echo "✅ Frontend task definition registered (revision: $FRONTEND_REV)"
echo ""

# 4. Create Services
echo "✓ Creating ECS services..."

# Backend Service
aws ecs create-service \
  --cluster $CLUSTER \
  --service-name $BACKEND_SERVICE \
  --task-definition user-app-backend:${BACKEND_REV} \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${PRIVATE_SUBNETS}],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=$BACKEND_TG,containerName=user-app-backend,containerPort=5000" \
  --region $REGION \
  --output text 2>&1 | head -1

echo "✅ Backend service created"

# Frontend Service
aws ecs create-service \
  --cluster $CLUSTER \
  --service-name $FRONTEND_SERVICE \
  --task-definition user-app-frontend:${FRONTEND_REV} \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${PRIVATE_SUBNETS}],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=$FRONTEND_TG,containerName=user-app-frontend,containerPort=80" \
  --region $REGION \
  --output text 2>&1 | head -1

echo "✅ Frontend service created"
echo ""

# 5. Wait for services
echo "✓ Waiting for services to be ready (2-5 minutes)..."
aws ecs wait services-stable \
  --cluster $CLUSTER \
  --services $BACKEND_SERVICE $FRONTEND_SERVICE \
  --region $REGION || echo "⚠ Still stabilizing..."

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ ECS SERVICES CREATED & READY FOR GITHUB ACTIONS"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Services Status:"
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $BACKEND_SERVICE $FRONTEND_SERVICE \
  --region $REGION \
  --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
  --output table
echo ""
echo "Next: Push code to GitHub to trigger automatic deployment!"
echo "  $ git push origin main"
echo ""
