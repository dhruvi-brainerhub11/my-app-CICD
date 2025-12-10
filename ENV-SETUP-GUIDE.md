# Environment Variables Setup Guide

## Overview
This guide explains how to manage environment variables for local development, Docker Compose, and AWS ECS Fargate deployment.

---

## 1. Local Development Setup

### Backend (.env for local development)
Create `backend/.env` in your local machine:

```bash
# RDS Database Configuration (for local: use docker-compose or local MySQL)
DB_HOST=localhost
DB_PORT=3306
DB_USER=admin
DB_PASSWORD=admin123
DB_NAME=user_app_db

# Server Configuration
PORT=5000
NODE_ENV=development

# CORS Configuration (for local React dev server on port 3000)
CORS_ORIGIN=http://localhost:3000
```

### Frontend (.env for local development)
Create `frontend/.env` in your local machine:

```bash
# API Configuration (points to local backend)
REACT_APP_API_URL=http://localhost:5000
REACT_APP_API_TIMEOUT=30000
```

### Running Locally
```bash
# Backend
cd backend
npm install
npm start  # Runs on http://localhost:5000

# Frontend (in another terminal)
cd frontend
npm install
npm start  # Runs on http://localhost:3000
```

---

## 2. Docker Compose Setup (Local with Docker)

### Configuration
The `docker-compose.yml` has environment variables for the services:

```yaml
services:
  mysql:
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: user_app_db
      MYSQL_USER: admin
      MYSQL_PASSWORD: admin123
  
  backend:
    environment:
      DB_HOST: mysql        # Docker service name
      DB_PORT: 3306
      DB_USER: admin
      DB_PASSWORD: admin123
      DB_NAME: user_app_db
      PORT: 5000
      NODE_ENV: development
      CORS_ORIGIN: http://localhost  # Frontend on port 80
  
  frontend:
    environment:
      REACT_APP_API_URL: http://localhost:5000
```

### Running with Docker Compose
```bash
# Start all services
docker-compose up -d

# Access:
# - Frontend: http://localhost
# - Backend API: http://localhost:5000/api/users
# - Backend health: http://localhost:5000/api/health
```

---

## 3. AWS ECS Fargate Deployment

### Step 1: Update `.env.example` Files
These are templates for production. Update them with your AWS values:

**`backend/.env.example` (Production)**
```
DB_HOST=myappdb.c9oq2ky8kisq.ap-south-1.rds.amazonaws.com
DB_PORT=3306
DB_USER=admin
DB_PASSWORD=Admin123
DB_NAME=myappdb
PORT=5000
NODE_ENV=production
CORS_ORIGIN=http://my-app-alb-1553941597.ap-south-1.elb.amazonaws.com
```

**`frontend/.env.example` (Production)**
```
REACT_APP_API_URL=http://my-app-alb-1553941597.ap-south-1.elb.amazonaws.com
REACT_APP_API_TIMEOUT=30000
```

### Step 2: Set GitHub Secrets for CI/CD
Go to: `https://github.com/dhruvi-brainerhub11/my-app-CICD/settings/secrets/actions`

Add these secrets:
```
AWS_ACCESS_KEY_ID: your-aws-access-key
AWS_SECRET_ACCESS_KEY: your-aws-secret-key
AWS_REGION: ap-south-1
```

### Step 3: ECS Task Definition Environment Variables
The ECS task definitions should reference:

**Backend Task Definition** (in AWS console or via CLI):
```json
{
  "containerDefinitions": [
    {
      "name": "user-app-backend",
      "environment": [
        {
          "name": "DB_HOST",
          "value": "myappdb.c9oq2ky8kisq.ap-south-1.rds.amazonaws.com"
        },
        {
          "name": "DB_PORT",
          "value": "3306"
        },
        {
          "name": "DB_USER",
          "value": "admin"
        },
        {
          "name": "DB_PASSWORD",
          "value": "Admin123"
        },
        {
          "name": "DB_NAME",
          "value": "myappdb"
        },
        {
          "name": "PORT",
          "value": "5000"
        },
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "CORS_ORIGIN",
          "value": "http://my-app-alb-1553941597.ap-south-1.elb.amazonaws.com"
        }
      ]
    }
  ]
}
```

**Frontend Task Definition** (in AWS console or via CLI):
```json
{
  "containerDefinitions": [
    {
      "name": "user-app-frontend",
      "environment": [
        {
          "name": "REACT_APP_API_URL",
          "value": "http://my-app-alb-1553941597.ap-south-1.elb.amazonaws.com"
        },
        {
          "name": "REACT_APP_API_TIMEOUT",
          "value": "30000"
        }
      ]
    }
  ]
}
```

### Step 4: Recommended: Use AWS Secrets Manager
For sensitive data like DB passwords, use AWS Secrets Manager instead of plain text:

1. Create secret in AWS Secrets Manager:
   ```bash
   aws secretsmanager create-secret \
     --name user-app-db-password \
     --secret-string "Admin123" \
     --region ap-south-1
   ```

2. Reference in task definition:
   ```json
   {
     "name": "DB_PASSWORD",
     "valueFrom": "arn:aws:secretsmanager:ap-south-1:123456789:secret:user-app-db-password:password::"
   }
   ```

---

## 4. Environment Variables Reference

### Backend Variables
| Variable | Local Dev | Docker Compose | ECS Fargate |
|----------|-----------|-----------------|------------|
| DB_HOST | localhost | mysql (service) | RDS endpoint |
| DB_USER | admin | admin | admin |
| DB_PASSWORD | admin123 | admin123 | AWS Secrets Mgr |
| DB_NAME | user_app_db | user_app_db | myappdb |
| PORT | 5000 | 5000 | 5000 |
| NODE_ENV | development | development | production |
| CORS_ORIGIN | http://localhost:3000 | http://localhost | ALB URL |

### Frontend Variables
| Variable | Local Dev | Docker Compose | ECS Fargate |
|----------|-----------|-----------------|------------|
| REACT_APP_API_URL | http://localhost:5000 | http://localhost:5000 | ALB URL |

---

## 5. Deployment Workflow

### When You Push to GitHub (main branch):
1. **Build & Push to ECR** (via `build-push-ecr.yml`):
   - Builds Docker images for backend & frontend
   - Tags with commit SHA
   - Pushes to AWS ECR

2. **Deploy to ECS** (via `deploy-ecs.yml`):
   - Updates task definitions with new image
   - Deploys to ECS Fargate services
   - Services use environment variables from task definitions

### Command to Trigger Manually:
```bash
git commit -m "Update code"
git push origin main
# GitHub Actions will automatically run workflows
```

---

## 6. Verification Checklist

- [ ] `backend/.env.example` has correct RDS endpoint and CORS origin
- [ ] `frontend/.env.example` has correct API URL (ALB endpoint)
- [ ] GitHub Secrets are set (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
- [ ] ECS Task Definitions have correct environment variables
- [ ] ALB is pointing to correct backend/frontend services
- [ ] Security Groups allow communication between ALB, services, and RDS
- [ ] RDS security group allows inbound on port 3306 from ECS tasks

---

## 7. Troubleshooting

### Frontend can't reach backend
1. Check `REACT_APP_API_URL` is correct ALB endpoint
2. Check ALB security group allows traffic on port 80/443
3. Check backend security group allows inbound from ALB

### Backend can't reach RDS
1. Check `DB_HOST` is correct RDS endpoint
2. Check RDS security group allows inbound on port 3306
3. Check DB credentials in task definition match RDS

### CORS errors
1. Ensure `CORS_ORIGIN` in backend matches frontend origin
2. For ALB: should be `http://alb-dns-name` (no path)

---

## 8. Quick Reference

```bash
# Local development
npm start (both backend and frontend in separate terminals)

# Docker Compose
docker-compose up -d

# Deploy to ECS (automatic on git push)
git push origin main

# Check ECS deployment status
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1
```
