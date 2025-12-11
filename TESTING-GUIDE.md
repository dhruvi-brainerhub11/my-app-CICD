# 🧪 AWS ECS AUTOMATION - TESTING GUIDE

## Quick Test Overview

This guide helps you test the AWS ECS automation at each step.

---

## ✅ PRE-DEPLOYMENT TESTS (Local)

### 1. Verify All Scripts Exist

```bash
cd /home/admin01/Dhruvi/user-app
ls -lh aws/*.sh
```

**Expected Output:**
```
-rwxr-xr-x aws/setup-complete-infrastructure.sh
-rwxr-xr-x aws/deploy-ecs-services.sh
-rwxr-xr-x aws/complete-deployment.sh
```

### 2. Test Docker Builds (Optional but Recommended)

```bash
# Test backend build
cd backend
docker build -t test-backend:latest .
docker images | grep test-backend

# Test frontend build
cd ../frontend
docker build -t test-frontend:latest .
docker images | grep test-frontend
```

**Expected:**
- Both images build successfully
- Images appear in `docker images` output

### 3. Verify Git Configuration

```bash
git config user.name
git config user.email
git remote -v
```

**Expected:**
- User name and email configured
- Remote URL points to your GitHub repo
- Branch is `main`

### 4. Check AWS CLI Installation

```bash
aws --version
aws sts get-caller-identity
```

**Expected:**
- AWS CLI version 2.x installed
- Returns your AWS account info (or error if credentials not set)

### 5. Verify Environment Files

```bash
# Check frontend .env
cat frontend/.env

# Check backend .env
cat backend/.env

# Check .env.example files
cat backend/.env.example
```

**Expected Output for Frontend .env:**
```
REACT_APP_API_URL=http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com
```

**Expected Output for Backend .env:**
```
DB_HOST=user-app-db.c9xxxxxxxx.ap-south-1.rds.amazonaws.com
DB_PORT=3306
DB_USER=admin
DB_PASSWORD=Admin123456!
DB_NAME=myappdb
PORT=5000
NODE_ENV=production
CORS_ORIGIN=http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com
```

---

## 🧪 INFRASTRUCTURE SETUP TEST

### Phase 1: Dry Run (Optional but Safe)

Before running the actual setup, do a syntax check:

```bash
bash -n aws/setup-complete-infrastructure.sh
```

**Expected:** No output (means syntax is correct)

### Phase 2: Run Infrastructure Setup

```bash
bash aws/setup-complete-infrastructure.sh
```

**This will:**
- Take ~15 minutes
- Create VPC, subnets, security groups
- Create ALB with target groups
- Create RDS database
- Create ECS cluster
- Create CloudWatch logs
- Create ECR repositories
- Create IAM roles

**Expected Output:**
```
Starting AWS infrastructure setup...
Creating VPC...
✓ VPC created: vpc-xxxxxxxx
Creating Subnets...
✓ Public Subnet 1a: subnet-xxxxxxxx
✓ Public Subnet 1b: subnet-xxxxxxxx
✓ Private Subnet 1a: subnet-xxxxxxxx
✓ Private Subnet 1b: subnet-xxxxxxxx
...
Setup Complete!
Configuration saved to: aws-infrastructure-config.json
```

### Phase 3: Verify Infrastructure Created

After setup completes, verify in AWS Console:

**1. Check VPC:**
```bash
aws ec2 describe-vpcs \
  --filters Name=cidr,Values=10.0.0.0/16 \
  --region ap-south-1 \
  --query 'Vpcs[0].VpcId' \
  --output text
```

**2. Check ECS Cluster:**
```bash
aws ecs describe-clusters \
  --clusters user-app-cluster \
  --region ap-south-1 \
  --query 'clusters[0].clusterName'
```

**3. Check ALB:**
```bash
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?LoadBalancerName=='user-app-alb'].DNSName" \
  --region ap-south-1 \
  --output text
```

**4. Check RDS:**
```bash
aws rds describe-db-instances \
  --db-instance-identifier user-app-db \
  --region ap-south-1 \
  --query 'DBInstances[0].Endpoint.Address'
```

**5. Check Configuration File:**
```bash
cat aws-infrastructure-config.json | jq .
```

**Expected:** All resources created successfully with IDs saved in config file

---

## 🔄 DEPLOYMENT TEST

### Phase 1: GitHub Secrets Setup Test

Before deploying, verify GitHub Secrets are set:

```bash
# List (won't show values, for security)
echo "GitHub Secrets configured:"
echo "1. AWS_ACCESS_KEY_ID - ${AWS_ACCESS_KEY_ID:0:5}..."
echo "2. AWS_SECRET_ACCESS_KEY - configured"
echo "3. AWS_REGION - ap-south-1"
```

**Manual Check:**
1. Go to GitHub repo: Settings → Secrets and variables → Actions
2. Should see 3 secrets listed:
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY  
   - AWS_REGION

### Phase 2: Manual Deployment Test

```bash
bash aws/complete-deployment.sh
```

**This will:**
- Check prerequisites
- Build Docker images
- Push to ECR
- Register task definitions
- Create/update ECS services
- Monitor deployment
- Report status

**Expected Output:**
```
Checking prerequisites...
✓ Docker is installed
✓ AWS CLI is installed
✓ jq is installed
✓ git is installed

Building Docker images...
✓ Backend image built
✓ Frontend image built

Logging into ECR...
✓ ECR login successful

Pushing images...
✓ Backend image pushed
✓ Frontend image pushed

Registering task definitions...
✓ Backend task definition registered
✓ Frontend task definition registered

Creating/Updating services...
✓ Backend service created
✓ Frontend service created

Monitoring deployment...
Waiting for services to be stable... (this takes 2-5 minutes)
✓ All services stable!

Deployment complete!
Application URL: http://user-app-alb-xxx.ap-south-1.elb.amazonaws.com
```

### Phase 3: Check Deployment Status

```bash
# Check service status
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1 \
  --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
  --output table
```

**Expected:**
```
| serviceName                | status   | runningCount | desiredCount |
|---------------------------|----------|--------------|--------------|
| user-app-backend-service  | ACTIVE   | 2            | 2            |
| user-app-frontend-service | ACTIVE   | 2            | 2            |
```

### Phase 4: Check Task Status

```bash
# List running tasks
aws ecs list-tasks \
  --cluster user-app-cluster \
  --region ap-south-1 \
  --query 'taskArns'
```

**Expected:** 4 task ARNs (2 backend, 2 frontend)

### Phase 5: Check ALB Health

```bash
# Get target groups
aws elbv2 describe-target-groups \
  --load-balancer-arn $(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?LoadBalancerName=='user-app-alb'].LoadBalancerArn" \
    --region ap-south-1 --output text) \
  --region ap-south-1 \
  --query 'TargetGroups[*].[TargetGroupName,TargetType]' \
  --output table

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --query "TargetGroups[?TargetGroupName=='user-app-backend-tg'].TargetGroupArn" \
    --region ap-south-1 --output text) \
  --region ap-south-1 \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table
```

**Expected:**
- Both target groups exist
- Targets show "healthy" state

---

## 🌐 APPLICATION FUNCTIONALITY TEST

### Phase 1: Get ALB DNS

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?LoadBalancerName=='user-app-alb'].DNSName" \
  --region ap-south-1 \
  --output text)

echo "Application URL: http://$ALB_DNS"
```

### Phase 2: Test Frontend Access

```bash
curl -I http://$ALB_DNS
```

**Expected:**
```
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 1234
```

### Phase 3: Test Backend API

```bash
curl http://$ALB_DNS/api/health
```

**Expected:**
```json
{"status":"ok","message":"Backend is running"}
```

### Phase 4: Test Frontend to Backend Connection

1. Open browser: `http://$ALB_DNS`
2. Open Developer Console (F12)
3. Check Network tab - should see API calls to backend
4. Check Console tab - should be no CORS errors

**Expected:**
- Frontend page loads
- No red errors in console
- API calls successful (200 status)

### Phase 5: Test Database Connection

```bash
# Check backend logs for DB connection
aws logs tail /ecs/user-app-backend --follow --region ap-south-1

# Look for: "Connected to database" or similar message
```

**Expected:** Logs show successful database connection

---

## 📊 MONITORING & LOGS TEST

### Check CloudWatch Logs

```bash
# Backend logs
aws logs tail /ecs/user-app-backend --follow --region ap-south-1

# Frontend logs (if available)
aws logs tail /ecs/user-app-frontend --follow --region ap-south-1

# Show last 50 lines
aws logs tail /ecs/user-app-backend --max-items 50 --region ap-south-1
```

### Check Service Metrics

```bash
# Get CPU/Memory metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=user-app-backend-service \
               Name=ClusterName,Value=user-app-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region ap-south-1
```

---

## 🚀 CI/CD TEST (GitHub Actions)

### Phase 1: Trigger Deployment via Git Push

```bash
# Make a small change to test CI/CD
echo "# Updated: $(date)" >> README.md
git add README.md
git commit -m "test: Trigger CI/CD pipeline"
git push origin main
```

### Phase 2: Monitor GitHub Actions

1. Go to GitHub repo
2. Click "Actions" tab
3. Should see workflow running
4. Click on the workflow to see logs

**Expected:**
- Workflow starts automatically
- Build step completes
- Push to ECR step completes
- Deploy to ECS step completes
- All steps show ✅

### Phase 3: Verify New Deployment

After GitHub Actions completes:

```bash
# Check if new task definitions created
aws ecs describe-task-definition \
  --task-definition user-app-backend:latest \
  --region ap-south-1 \
  --query 'taskDefinition.revision'
```

**Expected:** Revision number increases with each deploy

---

## 🧹 CLEANUP TEST (Optional)

If you want to test cleanup:

```bash
# View what will be deleted (manual check first)
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1

# DO NOT RUN unless you want to delete everything:
# bash aws/cleanup-infrastructure.sh
```

---

## ✅ TESTING CHECKLIST

### Pre-Deployment ✅
- [ ] All scripts exist and are executable
- [ ] Docker images build successfully (optional)
- [ ] Git is configured correctly
- [ ] AWS CLI works and credentials set
- [ ] Environment files have correct values

### Infrastructure Setup ✅
- [ ] Infrastructure script runs without errors
- [ ] VPC created with correct CIDR
- [ ] Subnets created (2 public, 2 private)
- [ ] ALB created
- [ ] RDS created
- [ ] ECS cluster created
- [ ] CloudWatch logs created
- [ ] ECR repositories created
- [ ] Configuration saved to JSON

### Deployment ✅
- [ ] Deployment script runs without errors
- [ ] Docker images built
- [ ] Images pushed to ECR
- [ ] Task definitions registered
- [ ] ECS services created
- [ ] 2 backend tasks running
- [ ] 2 frontend tasks running
- [ ] ALB health checks passing

### Application ✅
- [ ] Frontend accessible at ALB DNS
- [ ] Backend API responds to requests
- [ ] Frontend connects to backend
- [ ] Backend connects to RDS
- [ ] No errors in logs
- [ ] No CORS errors

### CI/CD ✅
- [ ] GitHub Actions workflow exists
- [ ] Workflow triggers on git push
- [ ] Build step completes
- [ ] Push to ECR step completes
- [ ] Deploy step completes
- [ ] New tasks deployed

---

## 🆘 TROUBLESHOOTING DURING TESTING

### Infrastructure Setup Fails
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check IAM permissions - script will tell you which service failed
# Read the error message carefully
```

### Deployment Fails
```bash
# Check Docker daemon
docker ps

# Check AWS credentials in environment
echo $AWS_ACCESS_KEY_ID
echo $AWS_REGION

# Check ECR repositories exist
aws ecr describe-repositories --region ap-south-1
```

### Health Checks Failing
```bash
# Check task logs
aws logs tail /ecs/user-app-backend --follow --region ap-south-1

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:... \
  --region ap-south-1
```

### Application Not Responding
```bash
# Check if tasks are running
aws ecs list-tasks --cluster user-app-cluster --region ap-south-1

# Check if ALB is routing traffic
aws elbv2 describe-listeners \
  --load-balancer-arn arn:aws:... \
  --region ap-south-1
```

---

## 📋 TESTING TIMELINE

**Recommended Testing Order:**

1. **Pre-Deployment Tests** (5 minutes)
   - Verify scripts, Docker, AWS CLI, environment

2. **Infrastructure Setup Test** (15 minutes)
   - Run setup script and wait for completion
   - Verify all resources created

3. **Deployment Test** (15 minutes)
   - Run deployment script
   - Wait for services to stabilize
   - Verify all tasks running

4. **Application Functionality Test** (5 minutes)
   - Test frontend access
   - Test API endpoints
   - Test database connection

5. **Monitoring & Logs Test** (5 minutes)
   - Check CloudWatch logs
   - Verify metrics are being collected

6. **CI/CD Test** (5 minutes)
   - Push code change
   - Monitor GitHub Actions
   - Verify automatic deployment

**Total Testing Time: ~50 minutes**

---

## 📞 QUICK REFERENCE COMMANDS

```bash
# Get ALB DNS
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?LoadBalancerName=='user-app-alb'].DNSName" \
  --region ap-south-1 --output text

# Get service status
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1 --query 'services[*].[serviceName,status]' --output table

# View logs
aws logs tail /ecs/user-app-backend --follow --region ap-south-1

# Check running tasks
aws ecs list-tasks --cluster user-app-cluster --region ap-south-1

# Get RDS endpoint
aws rds describe-db-instances \
  --db-instance-identifier user-app-db \
  --region ap-south-1 --query 'DBInstances[0].Endpoint.Address'
```

---

**You're ready to test! Start with Pre-Deployment Tests and work your way through. 🚀**
