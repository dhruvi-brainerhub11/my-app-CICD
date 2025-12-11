# 🚀 DEPLOYMENT STEPS - READY TO DEPLOY

## ✅ Code Review Complete - All Issues Fixed

Your code has been reviewed and all critical issues have been fixed. Here's what to do next:

---

## Step 1: Test Locally (5 minutes)

Test that everything works on your machine before pushing to GitHub.

### 1.1 Start Docker Compose
```bash
cd /home/admin01/Dhruvi/user-app
docker-compose up -d
```

### 1.2 Wait for Services to Be Healthy
```bash
# Wait 30 seconds for MySQL to initialize
sleep 30

# Check services
docker-compose ps

# Should see:
# mysql         - healthy
# backend       - running
# frontend      - running
```

### 1.3 Test Backend API
```bash
# Test health check
curl http://localhost:5000/api/health

# Should return: {"status":"healthy","database":"connected"}
```

### 1.4 Test Frontend
```bash
# Open in browser
http://localhost

# Should see:
# - User Input Form
# - Users List
# - No console errors
```

### 1.5 Test Full Flow
1. Open `http://localhost` in browser
2. Fill the form with a name
3. Click "Add User"
4. User should appear in the list
5. Click delete on the user
6. User should disappear

### 1.6 If Tests Pass ✅
```bash
# Stop services
docker-compose down

# Proceed to Step 2
```

### 1.7 If Tests Fail ❌
```bash
# Check logs
docker-compose logs backend
docker-compose logs frontend
docker-compose logs mysql

# Common issues:
# - Port 80 already in use: Change docker-compose.yml port to 8080:80
# - Database not initialized: Wait 30 seconds more
# - CORS errors: Check frontend console, verify API_URL
```

---

## Step 2: Commit and Push to GitHub (2 minutes)

All your fixes are ready to be pushed to GitHub.

### 2.1 Check What Changed
```bash
cd /home/admin01/Dhruvi/user-app
git status

# Should show modified:
# - frontend/.env
# - frontend/src/App.js
# - frontend/Dockerfile
# - docker-compose.yml
# - backend/.env.example

# Should show new:
# - backend/.env
# - CODE-REVIEW.md
# - FIXES-APPLIED.md
# - FINAL-REPORT.md
# - verify-fixes.sh
# - DEPLOYMENT-STEPS.md
```

### 2.2 Add and Commit Changes
```bash
git add .
git commit -m "fix: Resolve critical configuration issues for ECS deployment

- Update frontend ALB URL with correct DNS and http protocol
- Fix frontend fallback API URL with localhost:5000
- Fix Nginx port exposure from 3000 to 80
- Fix docker-compose port mapping to 80:80
- Create backend .env with RDS credentials
- Update backend .env.example with correct CORS origin
- Add comprehensive code review and deployment documentation"

git log -1  # Verify commit was created
```

### 2.3 Push to GitHub
```bash
git push origin main

# Output should show:
# Enumerating objects: ...
# Writing objects: 100% ...
# To github.com:dhruvi-brainerhub11/user-app.git
#    [commit-hash]...[commit-hash]  main -> main
```

### 2.4 Verify Push
```bash
# Go to GitHub and verify:
# https://github.com/dhruvi-brainerhub11/user-app

# Should see:
# - Latest commit message showing your changes
# - Branch should be "main"
```

---

## Step 3: Create GitHub Secrets (2 minutes)

GitHub Actions needs AWS credentials to deploy.

### 3.1 Get AWS Credentials

You need your AWS Access Key ID and Secret Access Key.

**Option A: If you have the AWS CLI configured**
```bash
# Check if configured
aws configure list

# Should show your credentials
```

**Option B: Get from AWS Console**
1. Go to [AWS Console](https://console.aws.amazon.com)
2. Search for "IAM"
3. Click "Users" 
4. Click your user
5. Click "Security Credentials"
6. Click "Create Access Key"
7. Copy the Access Key ID and Secret Access Key

⚠️ **Important**: Save the Secret Key safely - you can't retrieve it later!

### 3.2 Add GitHub Secrets

1. Go to [GitHub Repository Settings](https://github.com/dhruvi-brainerhub11/user-app/settings)
2. Click **"Secrets and variables"** → **"Actions"**
3. Click **"New repository secret"**

### 3.3 Add Secret #1: AWS_ACCESS_KEY_ID
- **Name**: `AWS_ACCESS_KEY_ID`
- **Value**: Your AWS access key from step 3.1
- Click **"Add secret"**

### 3.4 Add Secret #2: AWS_SECRET_ACCESS_KEY
- **Name**: `AWS_SECRET_ACCESS_KEY`
- **Value**: Your AWS secret access key from step 3.1
- Click **"Add secret"**

### 3.5 Verify Secrets Added
- Go back to Actions secrets page
- Should see both secrets listed (values hidden)

---

## Step 4: Create ECR Repositories (3 minutes)

GitHub Actions will push images to ECR. You need to create the repositories first.

### 4.1 Go to AWS ECR Console
1. Open [AWS Console](https://console.aws.amazon.com)
2. Search for "ECR"
3. Click "Elastic Container Registry"
4. Make sure region is **ap-south-1**

### 4.2 Create Backend Repository
1. Click **"Create repository"**
2. **Repository name**: `user-app-backend`
3. **Image tag mutability**: Immutable
4. **Scan on push**: Enabled
5. Click **"Create repository"**
6. Note the URI (looks like: `123456789.dkr.ecr.ap-south-1.amazonaws.com/user-app-backend`)

### 4.3 Create Frontend Repository
1. Click **"Create repository"**
2. **Repository name**: `user-app-frontend`
3. **Image tag mutability**: Immutable
4. **Scan on push**: Enabled
5. Click **"Create repository"**
6. Note the URI

### 4.4 Verify Repositories Created
```
✅ user-app-backend (URI: 123456789.dkr.ecr.ap-south-1.amazonaws.com/user-app-backend)
✅ user-app-frontend (URI: 123456789.dkr.ecr.ap-south-1.amazonaws.com/user-app-frontend)
```

---

## Step 5: Update ECS Task Definitions (5 minutes)

You have task definition files. You need to update them with your ECR URIs.

### 5.1 Get Your AWS Account ID
```bash
# If you have AWS CLI:
aws sts get-caller-identity --query Account --output text

# Or find in AWS Console → Account ID (top right)
# Format: 123456789012
```

### 5.2 Update backend-task-definition.json

File: `/home/admin01/Dhruvi/user-app/ecs/backend-task-definition.json`

Replace `YOUR_AWS_ACCOUNT_ID` with your actual account ID:
```json
"image": "YOUR_AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/user-app-backend:latest"
```

Also verify environment variables:
```json
"environment": [
  {"name": "DB_HOST", "value": "myappdb.c9oq2ky8kisq.ap-south-1.rds.amazonaws.com"},
  {"name": "DB_PORT", "value": "3306"},
  {"name": "DB_USER", "value": "admin"},
  {"name": "DB_PASSWORD", "value": "Admin123"},
  {"name": "DB_NAME", "value": "myappdb"},
  {"name": "PORT", "value": "5000"},
  {"name": "NODE_ENV", "value": "production"},
  {"name": "CORS_ORIGIN", "value": "http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com"}
]
```

### 5.3 Update frontend-task-definition.json

File: `/home/admin01/Dhruvi/user-app/ecs/frontend-task-definition.json`

Replace `YOUR_AWS_ACCOUNT_ID`:
```json
"image": "YOUR_AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/user-app-frontend:latest"
```

Also verify environment variables:
```json
"environment": [
  {"name": "REACT_APP_API_URL", "value": "http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com"}
]
```

### 5.4 Verify Port Mappings
- **Backend**: containerPort = 5000, hostPort = 5000
- **Frontend**: containerPort = 80, hostPort = 80

### 5.5 Register Task Definitions in ECS

**Option A: Via AWS CLI** (recommended)
```bash
cd /home/admin01/Dhruvi/user-app/ecs

# Register backend task definition
aws ecs register-task-definition \
  --cli-input-json file://backend-task-definition.json \
  --region ap-south-1

# Register frontend task definition
aws ecs register-task-definition \
  --cli-input-json file://frontend-task-definition.json \
  --region ap-south-1

# Verify registered
aws ecs list-task-definitions --region ap-south-1
```

**Option B: Via AWS Console**
1. Go to ECS → Task Definitions
2. Click "Create new task definition"
3. Paste JSON from backend-task-definition.json
4. Click "Create"
5. Repeat for frontend

---

## Step 6: Configure Security Groups (5 minutes)

### 6.1 ALB Security Group
1. Go to AWS Console → EC2 → Security Groups
2. Find security group associated with your ALB (user-app-alb-*)
3. **Inbound Rules** should allow:
   - HTTP (80) from 0.0.0.0/0
   - HTTPS (443) from 0.0.0.0/0 (if using SSL)

### 6.2 ECS Task Security Group
1. Find security group for ECS tasks (or create new)
2. **Inbound Rules** should allow:
   - Port 5000 from ALB Security Group (backend)
   - Port 80 from ALB Security Group (frontend)

### 6.3 RDS Security Group
1. Find security group for RDS database
2. **Inbound Rules** should allow:
   - MySQL (3306) from ECS Task Security Group

### 6.4 Verify Connectivity
```bash
# From your local machine, test ALB
curl http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com

# Should see frontend HTML or 503 (if tasks not running yet)
```

---

## Step 7: Deploy to ECS (2 minutes)

### 7.1 Update ECS Service (First Time Only)

If the ECS service doesn't exist, create it:

```bash
aws ecs create-service \
  --cluster user-app-cluster \
  --service-name user-app-backend-service \
  --task-definition user-app-backend:1 \
  --desired-count 2 \
  --load-balancers targetGroupArn=arn:aws:elasticloadbalancing:...,containerName=backend,containerPort=5000 \
  --region ap-south-1

aws ecs create-service \
  --cluster user-app-cluster \
  --service-name user-app-frontend-service \
  --task-definition user-app-frontend:1 \
  --desired-count 2 \
  --load-balancers targetGroupArn=arn:aws:elasticloadbalancing:...,containerName=frontend,containerPort=80 \
  --region ap-south-1
```

### 7.2 Trigger Deployment

Push to GitHub main branch:

```bash
# This is already done from Step 2!
# But you can push again to trigger redeployment:

git commit --allow-empty -m "Deploy to ECS"
git push origin main
```

### 7.3 Monitor GitHub Actions

1. Go to [GitHub Actions](https://github.com/dhruvi-brainerhub11/user-app/actions)
2. Click the latest workflow run
3. Monitor the build process:
   - ✅ Build images
   - ✅ Push to ECR
   - ✅ Deploy to ECS

Expected time: 5-10 minutes

### 7.4 Monitor ECS Deployment

While GitHub Actions runs:

1. Go to [AWS ECS Console](https://console.aws.amazon.com/ecs)
2. Click **"user-app-cluster"**
3. Click **"user-app-backend-service"**
4. Watch **"Deployments"** tab:
   - Status should go from "PRIMARY" to "ACTIVE"
   - Tasks should go from "PENDING" to "RUNNING"
5. Click **"user-app-frontend-service"**
6. Same process

Expected time: 5 minutes

### 7.5 Check ALB Target Health

1. Go to EC2 → Load Balancers
2. Click your ALB
3. Click "Target Groups"
4. Click each target group:
   - Targets should show "healthy" ✅
   - If "unhealthy" ❌, check security groups and task logs

---

## Step 8: Verify Production Deployment (5 minutes)

### 8.1 Test Frontend via ALB
```bash
# Open in browser
http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com

# Should see:
# - React application loaded
# - No console errors
# - User form visible
```

### 8.2 Test API via ALB
```bash
# Test health endpoint
curl http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com/api/health

# Should return:
# {"status":"healthy","database":"connected"}
```

### 8.3 Test Full Workflow
1. Add a user via the form
2. See user in the list
3. Delete user
4. Verify deletion works

### 8.4 Check Application Logs
```bash
# Backend logs
aws logs tail /ecs/user-app-backend --follow --region ap-south-1

# Frontend logs (in browser console at http://ALB-DNS)
# Should see API calls to http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com/api/...
```

### 8.5 Monitor CloudWatch
1. Go to CloudWatch → Log Groups
2. Should see:
   - `/ecs/user-app-backend` (application logs)
   - `/ecs/user-app-frontend` (access logs)
3. Check for errors

---

## Troubleshooting

### Issue: "Unknown host" or API not responding

**Cause**: CORS or DNS configuration
**Solution**:
```bash
# Verify ALB DNS resolves
nslookup user-app-alb-508171731.ap-south-1.elb.amazonaws.com

# Verify security group allows connections
# Check backend environment variable: CORS_ORIGIN
```

### Issue: Frontend loads but can't fetch users

**Cause**: API URL configuration
**Solution**:
```bash
# Check browser console (F12 → Console tab)
# Should see API calls to: http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com/api/...

# If not, update frontend .env.example and redeploy
```

### Issue: ECS tasks won't start (STOPPED)

**Cause**: Task definition issue or insufficient resources
**Solution**:
```bash
# Check task logs
aws ecs describe-tasks --cluster user-app-cluster --tasks <task-arn> --region ap-south-1

# Check CloudWatch logs
aws logs tail /ecs/user-app-backend --region ap-south-1

# Common issue: Check image URI in task definition
```

### Issue: ALB targets showing "unhealthy"

**Cause**: Health check failing
**Solution**:
```bash
# Check health check endpoint in target group
# Should be: /api/health for backend, / for frontend

# Test from ECS task:
aws ecs execute-command \
  --cluster user-app-cluster \
  --task <task-id> \
  --container backend \
  --interactive \
  --command "/bin/sh"

# Inside container:
curl localhost:5000/api/health
```

---

## Success Checklist ✅

### Local Testing
- [ ] `docker-compose up -d` works
- [ ] Frontend accessible at `http://localhost`
- [ ] API responds at `http://localhost:5000/api/health`
- [ ] Can add/delete users
- [ ] No errors in console or logs

### GitHub Setup
- [ ] Code pushed to main branch
- [ ] GitHub Secrets added (2 secrets)
- [ ] GitHub Actions can see the secrets

### AWS Infrastructure
- [ ] ECR repositories created (2 repos)
- [ ] Task definitions registered (2 definitions)
- [ ] Security groups configured
- [ ] ALB configured with target groups
- [ ] RDS accessible from ECS tasks

### Deployment
- [ ] GitHub Actions build succeeded
- [ ] Images pushed to ECR
- [ ] ECS tasks in RUNNING status
- [ ] ALB targets healthy
- [ ] Frontend loads via ALB DNS
- [ ] API responds via ALB DNS
- [ ] Full workflow works (add/delete users)

---

## Summary

You're just **3 steps** away from production:

1. ✅ **Test Locally** - 5 minutes
2. ✅ **Push to GitHub** - 2 minutes (already done)
3. ⏳ **Set Up GitHub Secrets** - 2 minutes
4. ⏳ **Create ECR Repositories** - 3 minutes
5. ⏳ **Update Task Definitions** - 5 minutes
6. ⏳ **Configure Security Groups** - 5 minutes
7. ⏳ **Deploy to ECS** - 2 minutes
8. ⏳ **Verify Deployment** - 5 minutes

**Total Time**: ~25 minutes

**Status**: Code is ready! 🚀

Next Step: Follow Step 1 (Test Locally) above
