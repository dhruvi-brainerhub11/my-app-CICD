# Deployment Checklist - Ready for ECS Fargate

## ✅ Code & Configuration Status

All configuration has been updated with your AWS infrastructure:

- ✅ **RDS Database**: `myappdb.c9oq2ky8kisq.ap-south-1.rds.amazonaws.com`
- ✅ **ALB DNS**: `user-app-alb-508171731.ap-south-1.elb.amazonaws.com`
- ✅ **RDS Credentials**: `admin / Admin123`
- ✅ **Backend Code**: Express.js API with MySQL connection
- ✅ **Frontend Code**: React app with ALB endpoint
- ✅ **Environment Files**: `.env` and `.env.example` configured
- ✅ **GitHub Workflows**: `deploy-ecs.yml` and `build-push-ecr.yml` ready
- ✅ **Code Pushed to GitHub**: `main` branch

---

## 🔐 Step 1: Configure GitHub Secrets (REQUIRED)

Your GitHub Actions workflows need AWS credentials to authenticate and push images to ECR.

### How to Add Secrets:

1. Go to: `https://github.com/dhruvi-brainerhub11/my-app-CICD/settings/secrets/actions`

2. Click **"New repository secret"** and add these 3 secrets:

```
Secret #1:
Name: AWS_ACCESS_KEY_ID
Value: (your AWS access key from AWS IAM)

Secret #2:
Name: AWS_SECRET_ACCESS_KEY
Value: (your AWS secret key from AWS IAM)

Secret #3:
Name: AWS_REGION
Value: ap-south-1
```

### Getting AWS Credentials:

If you don't have IAM access keys:

1. Go to **AWS Console** → **IAM** → **Users**
2. Select your user
3. Click **Security Credentials** tab
4. Under "Access keys", click **Create access key**
5. Choose **Command Line Interface (CLI)**
6. Copy the Access Key ID and Secret Access Key

⚠️ **IMPORTANT**: Store these securely. Never commit them to GitHub!

---

## 🏗️ Step 2: Create ECR Repositories (REQUIRED)

The GitHub workflow will push Docker images to ECR. You need to create the repositories first.

### Using AWS Console:

1. Go to **AWS Console** → **ECR (Elastic Container Registry)**
2. Click **Create Repository**
3. Create **Repository #1**:
   - Name: `user-app-backend`
   - Image scan: Optional
   - Encryption: Optional
   - Click **Create repository**

4. Create **Repository #2**:
   - Name: `user-app-frontend`
   - Click **Create repository**

### Using AWS CLI:

```bash
aws ecr create-repository \
  --repository-name user-app-backend \
  --region ap-south-1

aws ecr create-repository \
  --repository-name user-app-frontend \
  --region ap-south-1
```

---

## 🎯 Step 3: Update ECS Task Definitions

Your task definitions need environment variables to connect to RDS and ALB.

### Backend Task Definition

1. Go to **AWS Console** → **ECS** → **Task Definitions** → **user-app-backend**
2. Click **Create new revision**
3. Find the container definition **user-app-backend**
4. Click **Environment Variables** and add:

```json
[
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
    "value": "http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com"
  }
]
```

5. Click **Create**

### Frontend Task Definition

1. Go to **ECS** → **Task Definitions** → **user-app-frontend**
2. Click **Create new revision**
3. Find the container definition **user-app-frontend**
4. Click **Environment Variables** and add:

```json
[
  {
    "name": "REACT_APP_API_URL",
    "value": "http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com"
  },
  {
    "name": "REACT_APP_API_TIMEOUT",
    "value": "30000"
  }
]
```

5. Click **Create**

---

## 🛡️ Step 4: Configure Security Groups

Ensure your services can communicate:

### ECS Task Security Group

Allow **inbound** from ALB:
- Type: Custom TCP
- Port: 5000 (backend) or 80 (frontend)
- Source: ALB Security Group

Allow **outbound** to RDS:
- Type: Custom TCP
- Port: 3306
- Destination: RDS Security Group

### RDS Security Group

Allow **inbound** from ECS tasks:
- Type: MySQL/Aurora (3306)
- Source: ECS Task Security Group

### ALB Security Group

Allow **inbound**:
- Type: HTTP
- Port: 80
- Source: 0.0.0.0/0

---

## 🚀 Step 5: Deploy to ECS

### Option A: Automatic Deployment (via GitHub)

Simply push code to GitHub and the workflows will run automatically:

```bash
cd /home/admin01/Dhruvi/user-app

# Make any code changes, then:
git add .
git commit -m "Deploy to ECS"
git push origin main

# GitHub Actions will:
# 1. Build Docker images (build-push-ecr.yml)
# 2. Push images to ECR
# 3. Deploy to ECS (deploy-ecs.yml)
```

### Option B: Manual Deployment (via AWS CLI)

```bash
# Build images locally
docker-compose build

# Tag images
docker tag user-app-backend:latest <ECR_URI>/user-app-backend:latest
docker tag user-app-frontend:latest <ECR_URI>/user-app-frontend:latest

# Push to ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <ECR_URI>
docker push <ECR_URI>/user-app-backend:latest
docker push <ECR_URI>/user-app-frontend:latest

# Update ECS service
aws ecs update-service \
  --cluster user-app-cluster \
  --service user-app-backend-service \
  --force-new-deployment \
  --region ap-south-1
```

---

## ✅ Step 6: Verify Deployment

### Check Services Status

```bash
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1 \
  --query 'services[*].[serviceName,status,desiredCount,runningCount]' \
  --output table
```

Expected output:
```
| serviceName                | status | desiredCount | runningCount |
|----------------------------|--------|--------------|--------------|
| user-app-backend-service   | ACTIVE | 1            | 1            |
| user-app-frontend-service  | ACTIVE | 1            | 1            |
```

### Check Running Tasks

```bash
aws ecs list-tasks \
  --cluster user-app-cluster \
  --region ap-south-1
```

### View Logs

```bash
# Get log stream names
aws logs describe-log-streams \
  --log-group-name /ecs/user-app-backend \
  --region ap-south-1 \
  --order-by LastEventTime \
  --descending \
  --max-items 1

# View logs
aws logs get-log-events \
  --log-group-name /ecs/user-app-backend \
  --log-stream-name <stream-name> \
  --region ap-south-1 \
  --start-from-head
```

### Test Application

```bash
# Get ALB DNS (you already know it)
ALB_DNS="user-app-alb-508171731.ap-south-1.elb.amazonaws.com"

# Test health check
curl http://$ALB_DNS/api/health

# Get users list
curl http://$ALB_DNS/api/users

# Open in browser
# Frontend: http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com
```

---

## 📋 Checklist Summary

- [ ] **GitHub Secrets Added**: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
- [ ] **ECR Repositories Created**: user-app-backend, user-app-frontend
- [ ] **Backend Task Definition Updated**: Environment variables for RDS & CORS
- [ ] **Frontend Task Definition Updated**: Environment variables for ALB
- [ ] **Security Groups Configured**: ECS ↔ ALB, ECS ↔ RDS, ALB ↔ Internet
- [ ] **Code Pushed to GitHub**: main branch with all changes
- [ ] **GitHub Actions Triggered**: Both workflows (build-push-ecr, deploy-ecs) completed
- [ ] **Services Running**: Both ECS services show ACTIVE status
- [ ] **Application Tested**: Can access frontend and API via ALB

---

## 🔍 Troubleshooting

### Workflows Fail in GitHub Actions
- **Check**: GitHub Secrets are correctly set
- **Check**: AWS IAM user has `ecr:*` and `ecs:*` permissions
- **Check**: Repository names match workflow configuration

### ECS Service Won't Start
- **Check**: Task definition has correct environment variables
- **Check**: ECR image exists and is accessible
- **Check**: Task role has permission to pull from ECR
- **Check**: CloudWatch logs for error messages

### Frontend Can't Reach Backend
- **Check**: ALB target group health (should be HEALTHY)
- **Check**: Backend security group allows inbound from ALB
- **Check**: REACT_APP_API_URL matches ALB DNS
- **Check**: CORS_ORIGIN matches frontend origin

### Backend Can't Reach RDS
- **Check**: RDS security group allows inbound port 3306 from ECS
- **Check**: DB_HOST is correct RDS endpoint
- **Check**: DB credentials match RDS master password
- **Check**: Network connectivity (VPC, subnets, routing)

---

## 📞 Quick Reference

| Component | Endpoint |
|-----------|----------|
| **Frontend** | http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com |
| **Backend API** | http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com/api/users |
| **Health Check** | http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com/api/health |
| **RDS Database** | myappdb.c9oq2ky8kisq.ap-south-1.rds.amazonaws.com:3306 |
| **AWS Region** | ap-south-1 |
| **ECS Cluster** | user-app-cluster |

---

## 🎉 You're Ready!

All code is configured with your AWS infrastructure. Now:

1. ✅ Add GitHub Secrets
2. ✅ Create ECR repositories
3. ✅ Update Task Definitions
4. ✅ Configure Security Groups
5. ✅ Push code → Deployment starts automatically!

Good luck! 🚀
