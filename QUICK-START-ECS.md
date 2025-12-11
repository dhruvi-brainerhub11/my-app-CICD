# ⚡ QUICK START - Deploy to AWS ECS in 3 Steps

Complete automation for deploying your application to AWS ECS Fargate.

---

## 📋 Prerequisites (5 minutes)

1. **AWS Account** with IAM user access
2. **AWS CLI installed** and configured
3. **Docker installed** (for building images)
4. **Git installed**
5. **Code pushed to GitHub**

### Verify Setup

```bash
# Check AWS CLI
aws sts get-caller-identity
# Output should show your Account ID

# Check Docker
docker --version

# Check Git
git --version
```

---

## 🚀 Step 1: Create AWS Infrastructure (15 minutes)

Run this command once to create all AWS resources:

```bash
cd /home/admin01/Dhruvi/user-app
chmod +x aws/*.sh
bash aws/setup-complete-infrastructure.sh
```

**What this creates:**
- VPC with public & private subnets ✅
- Internet Gateway & NAT Gateway ✅
- Application Load Balancer (ALB) ✅
- Target Groups ✅
- RDS MySQL Database ✅
- ECS Fargate Cluster ✅
- CloudWatch Log Groups ✅
- ECR Repositories ✅
- IAM Roles ✅

**Time**: ~15 minutes (RDS takes longest)

**Output**: `aws-infrastructure-config.json`

---

## 🔐 Step 2: Add GitHub Secrets (2 minutes)

GitHub Actions needs AWS credentials to deploy.

1. Go to **GitHub** → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**

### Add Secret #1: AWS_ACCESS_KEY_ID
- Get from AWS Console → IAM → Users → Your User → Security Credentials
- Click **Create Access Key**
- Copy **Access Key ID**
- **Name**: `AWS_ACCESS_KEY_ID`
- **Value**: Paste access key ID
- Click **Add secret**

### Add Secret #2: AWS_SECRET_ACCESS_KEY
- From same AWS credentials page
- Copy **Secret Access Key**
- **Name**: `AWS_SECRET_ACCESS_KEY`
- **Value**: Paste secret access key
- Click **Add secret**

### Verify Secrets Added
- Go back to Actions secrets
- Should see both secrets listed (values hidden)

---

## 🚀 Step 3: Deploy (2 minutes)

### Option A: Automatic Deployment (GitHub Actions)

Push code to GitHub to automatically build and deploy:

```bash
cd /home/admin01/Dhruvi/user-app

# Make sure changes are committed
git add .
git commit -m "Deploy to ECS"

# Push to GitHub (triggers automatic deployment)
git push origin main

# Monitor in GitHub Actions tab
```

**GitHub Actions will automatically:**
1. Build Docker images ✅
2. Push to ECR ✅
3. Update ECS task definitions ✅
4. Deploy to ECS ✅
5. Monitor until stable ✅

**Time**: ~10 minutes

### Option B: Manual Deployment (Local)

Deploy immediately without pushing to GitHub:

```bash
cd /home/admin01/Dhruvi/user-app
bash aws/complete-deployment.sh
```

**This will:**
1. Build Docker images ✅
2. Login to ECR ✅
3. Push to ECR ✅
4. Register task definitions ✅
5. Create/Update ECS services ✅
6. Monitor deployment ✅

**Time**: ~15 minutes

---

## ✅ Verify Deployment Success

### Check Services are Running

```bash
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1 \
  --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
  --output table
```

Expected output:
```
│ user-app-backend-service  │ ACTIVE │ 2 │ 2 │
│ user-app-frontend-service │ ACTIVE │ 2 │ 2 │
```

### Get Application URL

```bash
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?LoadBalancerName=='user-app-alb'].DNSName" \
  --region ap-south-1 \
  --output text
```

Example output:
```
user-app-alb-508171731.ap-south-1.elb.amazonaws.com
```

### Open Application in Browser

```
http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com
```

### Test API

```bash
# Replace with your ALB DNS
ALB_DNS="user-app-alb-508171731.ap-south-1.elb.amazonaws.com"

# Test health check
curl http://$ALB_DNS/api/health

# Expected output:
# {"status":"healthy","database":"connected"}
```

### Test Full Workflow

1. Open `http://$ALB_DNS` in browser
2. Fill form with a name
3. Click "Add User"
4. User appears in list ✅
5. Click delete
6. User disappears ✅

---

## 🔄 Update Application

Every push to `main` branch automatically deploys:

```bash
# Make code changes
vi backend/src/index.js

# Commit and push
git add .
git commit -m "Update API"
git push origin main

# GitHub Actions automatically:
# 1. Builds new images
# 2. Pushes to ECR
# 3. Updates ECS services
# 4. Deploys new version
```

---

## 📊 Monitor Deployment

### View Real-time Logs

```bash
# Backend logs
aws logs tail /ecs/user-app-backend --follow --region ap-south-1

# Frontend logs
aws logs tail /ecs/user-app-frontend --follow --region ap-south-1
```

### Check Service Status

```bash
# Watch service status
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service \
  --region ap-south-1 \
  --query 'services[0].[serviceName,status,runningCount,desiredCount,deployments[0].status]' \
  --output table
```

### GitHub Actions Monitoring

1. Go to GitHub repository
2. Click **Actions** tab
3. Click workflow run to see details
4. Check for any failures

---

## 🛑 Troubleshooting

### GitHub Actions Build Fails

**Check logs:**
1. GitHub → Actions → Failed workflow
2. Click failed job
3. Expand failed step for error details

**Common issues:**
- AWS credentials incorrect → Check GitHub Secrets
- ECR repositories don't exist → Run Step 1 again
- Docker build fails → Check Dockerfile

### ECS Tasks Won't Start

```bash
# Check task logs
aws logs tail /ecs/user-app-backend --region ap-south-1

# Check service events
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service \
  --region ap-south-1 \
  --query 'services[0].events[0:3]'
```

**Common issues:**
- Image not found → Push images to ECR manually
- Database connection failure → Check RDS security group
- Out of memory → Increase task memory in task definition

### ALB Targets Unhealthy

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN> \
  --region ap-south-1
```

**Common issues:**
- Health check failing → Check health check path
- Security group blocking traffic → Check security groups
- Application not responding → Check logs

---

## 🚀 Production Checklist

- [ ] Application running on ECS ✅
- [ ] Health checks passing ✅
- [ ] Can add/delete users through API ✅
- [ ] Logs visible in CloudWatch ✅
- [ ] ALB DNS resolves ✅
- [ ] GitHub Actions working ✅
- [ ] Code pushed to GitHub ✅

---

## 📚 Full Documentation

For detailed information, see:
- [AWS-ECS-DEPLOYMENT-GUIDE.md](AWS-ECS-DEPLOYMENT-GUIDE.md) - Complete guide with troubleshooting
- [aws/README.md](aws/README.md) - AWS automation scripts overview
- [AWS-CLI-COMMANDS.md](aws/AWS-CLI-COMMANDS.md) - All AWS CLI commands used

---

## 📞 Quick Reference

```bash
# Infrastructure setup (Step 1)
bash aws/setup-complete-infrastructure.sh

# Manual deployment (Step 3, Option B)
bash aws/complete-deployment.sh

# Check services
aws ecs describe-services --cluster user-app-cluster --services user-app-backend-service user-app-frontend-service --region ap-south-1 --query 'services[*].[serviceName,status,runningCount,desiredCount]' --output table

# Get ALB DNS
aws elbv2 describe-load-balancers --query "LoadBalancers[?LoadBalancerName=='user-app-alb'].DNSName" --region ap-south-1 --output text

# View logs
aws logs tail /ecs/user-app-backend --follow --region ap-south-1
```

---

## ✅ You're Done!

Your application is now:
- ✅ Running on AWS ECS Fargate
- ✅ Behind a load balancer
- ✅ Connected to RDS database
- ✅ Auto-deploying with GitHub Actions
- ✅ Monitored with CloudWatch logs

**Next:** Update code and push to GitHub for automatic deployment! 🚀

---

**Need help?** See [AWS-ECS-DEPLOYMENT-GUIDE.md](AWS-ECS-DEPLOYMENT-GUIDE.md) for detailed troubleshooting.
