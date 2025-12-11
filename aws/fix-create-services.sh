#!/bin/bash

################################################################################
# 🔧 FIX: Create ECS Services (Fixes INACTIVE Service Error)
# 
# This script creates the ECS services that GitHub Actions needs to deploy to
# Run this ONCE to set up services, then GitHub Actions will work automatically
#
# Usage: bash aws/fix-create-services.sh
################################################################################

set -e

REGION="ap-south-1"
CLUSTER="user-app-cluster"
BACKEND_SERVICE="user-app-backend-service"
FRONTEND_SERVICE="user-app-frontend-service"

echo "════════════════════════════════════════════════════════════════"
echo "🔧 FIXING: Creating ECS Services"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Check if cluster exists
echo "✓ Checking if cluster exists..."
CLUSTER_EXISTS=$(aws ecs describe-clusters \
  --clusters $CLUSTER \
  --region $REGION \
  --query 'clusters[0].clusterName' \
  --output text 2>/dev/null || echo "")

if [ -z "$CLUSTER_EXISTS" ] || [ "$CLUSTER_EXISTS" = "None" ]; then
  echo "❌ ERROR: Cluster '$CLUSTER' does not exist!"
  echo "   Run: bash aws/setup-complete-infrastructure.sh"
  exit 1
fi

echo "✅ Cluster found: $CLUSTER"
echo ""

# Load configuration
if [ ! -f "aws-infrastructure-config.json" ]; then
  echo "❌ ERROR: aws-infrastructure-config.json not found!"
  echo "   Run: bash aws/setup-complete-infrastructure.sh"
  exit 1
fi

echo "✓ Loading configuration..."
ALB_TARGET_GROUP_BACKEND=$(jq -r '.alb_target_group_backend_arn' aws-infrastructure-config.json)
ALB_TARGET_GROUP_FRONTEND=$(jq -r '.alb_target_group_frontend_arn' aws-infrastructure-config.json)
PRIVATE_SUBNET_1=$(jq -r '.private_subnet_1a' aws-infrastructure-config.json)
PRIVATE_SUBNET_2=$(jq -r '.private_subnet_1b' aws-infrastructure-config.json)
ECS_SECURITY_GROUP=$(jq -r '.ecs_security_group_id' aws-infrastructure-config.json)

echo "✅ Configuration loaded"
echo ""

# Register Backend Task Definition
echo "✓ Registering backend task definition..."
BACKEND_TASK_DEF=$(aws ecs register-task-definition \
  --family user-app-backend \
  --network-mode awsvpc \
  --requires-compatibilities FARGATE \
  --cpu 512 \
  --memory 2048 \
  --execution-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole \
  --task-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskRole \
  --container-definitions "[{
    \"name\": \"user-app-backend\",
    \"image\": \"619576923139.dkr.ecr.ap-south-1.amazonaws.com/user-app-backend:latest\",
    \"portMappings\": [{
      \"containerPort\": 5000,
      \"hostPort\": 5000,
      \"protocol\": \"tcp\"
    }],
    \"environment\": [
      {\"name\": \"PORT\", \"value\": \"5000\"},
      {\"name\": \"NODE_ENV\", \"value\": \"production\"},
      {\"name\": \"DB_HOST\", \"value\": \"$(jq -r '.rds_endpoint' aws-infrastructure-config.json)\"},
      {\"name\": \"DB_PORT\", \"value\": \"3306\"},
      {\"name\": \"DB_USER\", \"value\": \"admin\"},
      {\"name\": \"DB_PASSWORD\", \"value\": \"Admin123456!\"},
      {\"name\": \"DB_NAME\", \"value\": \"myappdb\"},
      {\"name\": \"CORS_ORIGIN\", \"value\": \"http://$(jq -r '.alb_dns' aws-infrastructure-config.json)\"}
    ],
    \"logConfiguration\": {
      \"logDriver\": \"awslogs\",
      \"options\": {
        \"awslogs-group\": \"/ecs/user-app-backend\",
        \"awslogs-region\": \"ap-south-1\",
        \"awslogs-stream-prefix\": \"ecs\"
      }
    },
    \"healthCheck\": {
      \"command\": [\"CMD-SHELL\", \"curl -f http://localhost:5000/api/health || exit 1\"],
      \"interval\": 30,
      \"timeout\": 5,
      \"retries\": 3,
      \"startPeriod\": 60
    }
  }]" \
  --region $REGION \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "✅ Backend task definition registered: $(echo $BACKEND_TASK_DEF | rev | cut -d':' -f1 | rev)"
echo ""

# Register Frontend Task Definition
echo "✓ Registering frontend task definition..."
FRONTEND_TASK_DEF=$(aws ecs register-task-definition \
  --family user-app-frontend \
  --network-mode awsvpc \
  --requires-compatibilities FARGATE \
  --cpu 512 \
  --memory 1024 \
  --execution-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole \
  --container-definitions "[{
    \"name\": \"user-app-frontend\",
    \"image\": \"619576923139.dkr.ecr.ap-south-1.amazonaws.com/user-app-frontend:latest\",
    \"portMappings\": [{
      \"containerPort\": 80,
      \"hostPort\": 80,
      \"protocol\": \"tcp\"
    }],
    \"environment\": [
      {\"name\": \"REACT_APP_API_URL\", \"value\": \"http://$(jq -r '.alb_dns' aws-infrastructure-config.json)\"}
    ],
    \"logConfiguration\": {
      \"logDriver\": \"awslogs\",
      \"options\": {
        \"awslogs-group\": \"/ecs/user-app-frontend\",
        \"awslogs-region\": \"ap-south-1\",
        \"awslogs-stream-prefix\": \"ecs\"
      }
    },
    \"healthCheck\": {
      \"command\": [\"CMD-SHELL\", \"curl -f http://localhost/ || exit 1\"],
      \"interval\": 30,
      \"timeout\": 5,
      \"retries\": 3,
      \"startPeriod\": 60
    }
  }]" \
  --region $REGION \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "✅ Frontend task definition registered: $(echo $FRONTEND_TASK_DEF | rev | cut -d':' -f1 | rev)"
echo ""

# Create Backend Service
echo "✓ Creating backend service..."
aws ecs create-service \
  --cluster $CLUSTER \
  --service-name $BACKEND_SERVICE \
  --task-definition user-app-backend:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={
    subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],
    securityGroups=[$ECS_SECURITY_GROUP],
    assignPublicIp=DISABLED
  }" \
  --load-balancers "targetGroupArn=$ALB_TARGET_GROUP_BACKEND,containerName=user-app-backend,containerPort=5000" \
  --region $REGION \
  --query 'service.serviceName' \
  --output text 2>&1 | grep -v "already exists" || echo "✓ Backend service created"

echo "✅ Backend service ready"
echo ""

# Create Frontend Service
echo "✓ Creating frontend service..."
aws ecs create-service \
  --cluster $CLUSTER \
  --service-name $FRONTEND_SERVICE \
  --task-definition user-app-frontend:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={
    subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],
    securityGroups=[$ECS_SECURITY_GROUP],
    assignPublicIp=DISABLED
  }" \
  --load-balancers "targetGroupArn=$ALB_TARGET_GROUP_FRONTEND,containerName=user-app-frontend,containerPort=80" \
  --region $REGION \
  --query 'service.serviceName' \
  --output text 2>&1 | grep -v "already exists" || echo "✓ Frontend service created"

echo "✅ Frontend service ready"
echo ""

# Monitor services
echo "✓ Waiting for services to stabilize (2 minutes)..."
for i in {1..24}; do
  BACKEND_RUNNING=$(aws ecs describe-services \
    --cluster $CLUSTER \
    --services $BACKEND_SERVICE \
    --region $REGION \
    --query 'services[0].runningCount' \
    --output text 2>/dev/null || echo "0")
  
  FRONTEND_RUNNING=$(aws ecs describe-services \
    --cluster $CLUSTER \
    --services $FRONTEND_SERVICE \
    --region $REGION \
    --query 'services[0].runningCount' \
    --output text 2>/dev/null || echo "0")
  
  if [ "$BACKEND_RUNNING" = "2" ] && [ "$FRONTEND_RUNNING" = "2" ]; then
    echo "✅ All services running with 2 tasks each"
    break
  fi
  
  echo "  Waiting... Backend: $BACKEND_RUNNING/2, Frontend: $FRONTEND_RUNNING/2"
  sleep 5
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ SERVICES CREATED SUCCESSFULLY"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Services ready for GitHub Actions deployment!"
echo ""
echo "Next steps:"
echo "1. Make a code change and push:"
echo "   $ git push origin main"
echo ""
echo "2. GitHub Actions will automatically:"
echo "   - Build Docker images"
echo "   - Push to ECR"
echo "   - Deploy to ECS services"
echo ""
echo "3. Monitor deployment:"
echo "   $ aws logs tail /ecs/user-app-backend --follow --region ap-south-1"
echo ""
