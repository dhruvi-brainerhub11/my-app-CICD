#!/bin/bash

# AWS Configuration Update Script
# Replace the values below with your actual AWS infrastructure details

# ============================================
# REPLACE THESE WITH YOUR ACTUAL AWS VALUES
# ============================================

# RDS Configuration
export RDS_ENDPOINT="myappdb.c9oq2ky8kisq.ap-south-1.rds.amazonaws.com"
export RDS_PORT="3306"
export RDS_USER="admin"
export RDS_PASSWORD="Admin123"
export RDS_DATABASE="myappdb"

# ALB Configuration
export ALB_DNS_NAME="my-app-alb-1553941597.ap-south-1.elb.amazonaws.com"
export ALB_PROTOCOL="http"  # Change to https if using SSL certificate

# ECS Configuration
export ECS_CLUSTER_NAME="user-app-cluster"
export ECS_BACKEND_SERVICE="user-app-backend-service"
export ECS_FRONTEND_SERVICE="user-app-frontend-service"
export ECS_BACKEND_TASK_DEF="user-app-backend"
export ECS_FRONTEND_TASK_DEF="user-app-frontend"

# ECR Configuration
export ECR_BACKEND_REPO="user-app-backend"
export ECR_FRONTEND_REPO="user-app-frontend"
export AWS_REGION="ap-south-1"

# ============================================
# DO NOT MODIFY BELOW THIS LINE
# ============================================

echo "🔄 Updating configuration files with AWS values..."

# Update backend/.env.example
cat > backend/.env.example <<EOF
# RDS Database Configuration
DB_HOST=$RDS_ENDPOINT
DB_PORT=$RDS_PORT
DB_USER=$RDS_USER
DB_PASSWORD=$RDS_PASSWORD
DB_NAME=$RDS_DATABASE

# Server Configuration
PORT=5000
NODE_ENV=production

# CORS Configuration (ALB URL only, no path)
CORS_ORIGIN=$ALB_PROTOCOL://$ALB_DNS_NAME
EOF

echo "✓ Updated backend/.env.example"

# Update frontend/.env.example
cat > frontend/.env.example <<EOF
# API Configuration for Production
REACT_APP_API_URL=$ALB_PROTOCOL://$ALB_DNS_NAME
REACT_APP_API_TIMEOUT=30000
EOF

echo "✓ Updated frontend/.env.example"

# Update deploy-ecs.yml
cat > .github/workflows/deploy-ecs.yml <<EOF
name: Deploy to ECS Fargate

on:
  push:
    branches:
      - main
  workflow_dispatch:

env:
  AWS_REGION: $AWS_REGION
  ECS_CLUSTER: $ECS_CLUSTER_NAME
  ECS_SERVICE_BACKEND: $ECS_BACKEND_SERVICE
  ECS_SERVICE_FRONTEND: $ECS_FRONTEND_SERVICE
  ECS_TASK_DEFINITION_BACKEND: $ECS_BACKEND_TASK_DEF
  ECS_TASK_DEFINITION_FRONTEND: $ECS_FRONTEND_TASK_DEF

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: \${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: \${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: \${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Download Backend task definition
        run: |
          aws ecs describe-task-definition \\
            --task-definition \${{ env.ECS_TASK_DEFINITION_BACKEND }} \\
            --region \${{ env.AWS_REGION }} \\
            --query taskDefinition > backend-task-definition.json

      - name: Update Backend task definition
        id: backend-task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: backend-task-definition.json
          container-name: \${{ env.ECS_TASK_DEFINITION_BACKEND }}
          image: \${{ steps.login-ecr.outputs.registry }}/$ECR_BACKEND_REPO:\${{ github.sha }}

      - name: Deploy Backend to ECS
        uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: \${{ steps.backend-task-def.outputs.task-definition }}
          service: \${{ env.ECS_SERVICE_BACKEND }}
          cluster: \${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true

      - name: Download Frontend task definition
        run: |
          aws ecs describe-task-definition \\
            --task-definition \${{ env.ECS_TASK_DEFINITION_FRONTEND }} \\
            --region \${{ env.AWS_REGION }} \\
            --query taskDefinition > frontend-task-definition.json

      - name: Update Frontend task definition
        id: frontend-task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: frontend-task-definition.json
          container-name: \${{ env.ECS_TASK_DEFINITION_FRONTEND }}
          image: \${{ steps.login-ecr.outputs.registry }}/$ECR_FRONTEND_REPO:\${{ github.sha }}

      - name: Deploy Frontend to ECS
        uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: \${{ steps.frontend-task-def.outputs.task-definition }}
          service: \${{ env.ECS_SERVICE_FRONTEND }}
          cluster: \${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true

      - name: Deployment Summary
        run: |
          echo "✅ Successfully deployed to ECS Fargate"
          echo "Cluster: \${{ env.ECS_CLUSTER }}"
          echo "Region: \${{ env.AWS_REGION }}"
          echo "Backend Service: \${{ env.ECS_SERVICE_BACKEND }}"
          echo "Frontend Service: \${{ env.ECS_SERVICE_FRONTEND }}"
          echo "Backend Image: \${{ steps.login-ecr.outputs.registry }}/$ECR_BACKEND_REPO:\${{ github.sha }}"
          echo "Frontend Image: \${{ steps.login-ecr.outputs.registry }}/$ECR_FRONTEND_REPO:\${{ github.sha }}"
EOF

echo "✓ Updated .github/workflows/deploy-ecs.yml"

# Update build-push-ecr.yml
cat > .github/workflows/build-push-ecr.yml <<EOF
name: Build and Push to ECR

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

env:
  AWS_REGION: $AWS_REGION
  ECR_REGISTRY_BACKEND: $ECR_BACKEND_REPO
  ECR_REGISTRY_FRONTEND: $ECR_FRONTEND_REPO

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: \${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: \${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: \${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push Backend image
        id: build-backend
        env:
          ECR_REGISTRY: \${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: \${{ github.sha }}
        run: |
          docker build -t \$ECR_REGISTRY/\$ECR_REGISTRY_BACKEND:\$IMAGE_TAG -t \$ECR_REGISTRY/\$ECR_REGISTRY_BACKEND:latest ./backend
          docker push \$ECR_REGISTRY/\$ECR_REGISTRY_BACKEND:\$IMAGE_TAG
          docker push \$ECR_REGISTRY/\$ECR_REGISTRY_BACKEND:latest
          echo "image=\$ECR_REGISTRY/\$ECR_REGISTRY_BACKEND:\$IMAGE_TAG" >> \$GITHUB_OUTPUT

      - name: Build and push Frontend image
        id: build-frontend
        env:
          ECR_REGISTRY: \${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: \${{ github.sha }}
        run: |
          docker build -t \$ECR_REGISTRY/\$ECR_REGISTRY_FRONTEND:\$IMAGE_TAG -t \$ECR_REGISTRY/\$ECR_REGISTRY_FRONTEND:latest ./frontend
          docker push \$ECR_REGISTRY/\$ECR_REGISTRY_FRONTEND:\$IMAGE_TAG
          docker push \$ECR_REGISTRY/\$ECR_REGISTRY_FRONTEND:latest
          echo "image=\$ECR_REGISTRY/\$ECR_REGISTRY_FRONTEND:\$IMAGE_TAG" >> \$GITHUB_OUTPUT

      - name: Image digests
        run: |
          echo "Backend Image: \${{ steps.build-backend.outputs.image }}"
          echo "Frontend Image: \${{ steps.build-frontend.outputs.image }}"
EOF

echo "✓ Updated .github/workflows/build-push-ecr.yml"

echo ""
echo "✅ Configuration update complete!"
echo ""
echo "Updated files:"
echo "  - backend/.env.example"
echo "  - frontend/.env.example"
echo "  - .github/workflows/deploy-ecs.yml"
echo "  - .github/workflows/build-push-ecr.yml"
echo ""
echo "Next steps:"
echo "1. Review the updated files"
echo "2. Commit changes: git add . && git commit -m 'config: Update AWS infrastructure details'"
echo "3. Push to GitHub: git push origin main"
echo "4. Set GitHub Secrets in your repository settings"
