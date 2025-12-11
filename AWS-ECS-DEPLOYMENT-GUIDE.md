# 🚀 AWS ECS Complete Deployment Guide

## Overview

This guide will walk you through automating your entire AWS infrastructure and deployment process for the user-app using AWS CLI and GitHub Actions. After following this guide, you'll have:

- ✅ VPC with public and private subnets
- ✅ NAT Gateway for private subnet outbound
- ✅ Application Load Balancer (ALB) with routing
- ✅ RDS MySQL database
- ✅ ECS Fargate Cluster
- ✅ Backend and Frontend services running
- ✅ Automated CI/CD with GitHub Actions

**Total Setup Time**: ~30-40 minutes (RDS takes 5-10 minutes)

---

## Prerequisites

Before starting, ensure you have:

1. **AWS Account** with appropriate IAM permissions
2. **AWS CLI** installed and configured
3. **Docker** installed locally
4. **Git** installed
5. **jq** installed (for JSON parsing) - scripts will install if missing
6. **GitHub account** with code pushed to a public repo

### Install AWS CLI (if not installed)

```bash
# macOS
brew install awscli

# Ubuntu/Debian
sudo apt-get install awscli

# Verify installation
aws --version
aws configure  # Configure with your AWS credentials
```

### Verify Configuration

```bash
# Check AWS CLI is configured
aws sts get-caller-identity

# Output should show your Account ID and ARN
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet (0.0.0.0/0)                    │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
        ┌────────────────────────────────────┐
        │  Application Load Balancer (ALB)   │
        │        (Public Subnets)            │
        │  - Port 80 (HTTP)                  │
        │  - HTTPS (optional)                │
        └────┬──────────────────────┬────────┘
             │                      │
       ┌─────▼─────┐         ┌──────▼──────┐
       │ Frontend   │         │  Backend    │
       │ TG (80)    │         │  TG (5000)  │
       └─────┬─────┘         └──────┬──────┘
             │                      │
      ┌──────▼──────────────────────▼──────┐
      │    ECS Fargate Cluster              │
      │    (Private Subnets)                │
      │  - 2 Frontend Replicas              │
      │  - 2 Backend Replicas               │
      └──────┬──────────────────────┬──────┘
             │                      │
             └──────────┬───────────┘
                        │
                        ▼
              ┌──────────────────┐
              │  RDS MySQL       │
              │  (Private Subnet)│
              │  myappdb         │
              └──────────────────┘
```

---

## Step-by-Step Deployment Guide

### Step 1: Clone the Repository

```bash
# Navigate to your workspace
cd /home/admin01/Dhruvi

# Verify the user-app directory exists
cd user-app

# Verify you're on main branch
git status
```

### Step 2: Set Up AWS Infrastructure

This script will create:
- VPC with public and private subnets
- Internet Gateway and NAT Gateway
- Security Groups
- Application Load Balancer with target groups
- RDS MySQL Database
- ECS Cluster
- CloudWatch Log Groups
- ECR Repositories
- IAM Roles

**Run the infrastructure setup script:**

```bash
cd /home/admin01/Dhruvi/user-app

# Make scripts executable
chmod +x aws/*.sh

# Run infrastructure setup (THIS TAKES 10-15 MINUTES - RDS is the longest)
bash aws/setup-complete-infrastructure.sh
```

**Expected Output:**

```
╔════════════════════════════════════════════════════════════════╗
║  AWS ECS Complete Infrastructure Setup                          ║
║  Project: user-app
║  Region: ap-south-1
║  Account ID: 619576923139
╚════════════════════════════════════════════════════════════════╝

[INFO] Starting infrastructure setup...

[INFO] === STEP 1: Creating VPC and Networking ===
[✓] VPC created: vpc-0123456789abcdef0
[✓] DNS enabled for VPC
[✓] Public Subnet 1 created: subnet-...
... (more output)

[INFO] === STEP 4: Creating RDS Database ===
[✓] RDS instance created: user-app-db
[INFO] Waiting for RDS instance to be available (this may take 5-10 minutes)...
[✓] RDS instance is available at: user-app-db.c9oq2ky8kisq.ap-south-1.rds.amazonaws.com

... (more output)

╔════════════════════════════════════════════════════════════════╗
║  ✅ Infrastructure Setup Complete!                             ║
╚════════════════════════════════════════════════════════════════╝
```

**Save the Configuration File:**

After the script completes, you'll have `aws-infrastructure-config.json` in your directory. This file contains all the IDs and endpoints you'll need.

**View the configuration:**

```bash
cat aws-infrastructure-config.json | jq '.'
```

### Step 3: Set Up GitHub Secrets

Your GitHub Actions workflows need AWS credentials to deploy. Add these secrets to your GitHub repository:

1. Go to: **GitHub** → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**

**Add Secret #1: AWS_ACCESS_KEY_ID**
- **Name**: `AWS_ACCESS_KEY_ID`
- **Value**: Your AWS Access Key ID
- Click **Add secret**

**Add Secret #2: AWS_SECRET_ACCESS_KEY**
- **Name**: `AWS_SECRET_ACCESS_KEY`
- **Value**: Your AWS Secret Access Key
- Click **Add secret**

**Add Secret #3: AWS_REGION**
- **Name**: `AWS_REGION`
- **Value**: `ap-south-1`
- Click **Add secret**

You can get AWS credentials from:
1. AWS Console → IAM → Users → Your User → Security Credentials → Create Access Key

### Step 4: Update GitHub Workflows (if needed)

The workflow files are already configured, but verify they match your setup:

```bash
# Check the deploy workflow
cat .github/workflows/deploy-ecs.yml | head -20
```

The workflow should show:
```yaml
env:
  AWS_REGION: ap-south-1
  ECS_CLUSTER: user-app-cluster
  ECS_SERVICE_BACKEND: user-app-backend-service
  ECS_SERVICE_FRONTEND: user-app-frontend-service
```

### Step 5: Test Locally (Optional)

Before pushing to GitHub, test locally:

```bash
# Start local services
docker-compose up -d

# Wait for services to initialize
sleep 30

# Test backend API
curl http://localhost:5000/api/health

# Test frontend
open http://localhost  # or visit in browser

# Test adding a user
curl -X POST http://localhost:5000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User"}'

# Cleanup
docker-compose down
```

### Step 6: Push Code to GitHub

This will trigger the GitHub Actions workflow to build and deploy:

```bash
# Make sure all changes are committed
git status

# Add any changes
git add .

# Commit
git commit -m "feat: Add AWS infrastructure automation scripts

- Add complete-infrastructure.sh for VPC, ALB, RDS, ECS setup
- Add deploy-ecs-services.sh for automated ECS deployment
- Update task definitions with correct ports and ALB URL
- Add comprehensive deployment documentation"

# Push to GitHub (this triggers the workflow)
git push origin main
```

### Step 7: Monitor GitHub Actions Deployment

1. Go to **GitHub** → **Actions**
2. Click the latest workflow run
3. Monitor the build process:

```
Workflow: Deploy to ECS Fargate
├── Build Backend Image ✓
├── Build Frontend Image ✓
├── Push to ECR Backend ✓
├── Push to ECR Frontend ✓
├── Update ECS Task Definitions ✓
├── Deploy Backend Service ✓
├── Deploy Frontend Service ✓
└── Wait for Stability ✓
```

**Expected Time**: 5-10 minutes

### Step 8: Verify Deployment in AWS

While GitHub Actions runs, monitor your ECS cluster:

```bash
# Get cluster status
aws ecs describe-clusters \
  --clusters user-app-cluster \
  --region ap-south-1 \
  --query 'clusters[0]'

# Get service status
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1 \
  --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
  --output table

# Watch logs
aws logs tail /ecs/user-app-backend --follow --region ap-south-1
```

### Step 9: Access Your Application

Once deployment is complete:

```bash
# Get ALB DNS
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?LoadBalancerName=='user-app-alb'].DNSName" \
  --region ap-south-1 \
  --output text

# Output: user-app-alb-508171731.ap-south-1.elb.amazonaws.com
```

**Access your application:**
- **Frontend**: `http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com`
- **Backend API**: `http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com/api`
- **Health Check**: `http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com/api/health`

### Step 10: Test the Application

```bash
# Replace ALB_DNS with your actual ALB DNS
ALB_DNS="user-app-alb-508171731.ap-south-1.elb.amazonaws.com"

# Test backend health
curl "http://$ALB_DNS/api/health"

# Get all users
curl "http://$ALB_DNS/api/users"

# Add a new user
curl -X POST "http://$ALB_DNS/api/users" \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe"}'

# Get users again
curl "http://$ALB_DNS/api/users"
```

---

## Automated Deployment on Code Push

Now that everything is set up, any push to the `main` branch will automatically:

1. **Build** Docker images
2. **Test** the application
3. **Push** to ECR
4. **Update** ECS services
5. **Monitor** deployment until stable

### Workflow Trigger

```bash
# Any push to main triggers the workflow
git commit -m "your changes"
git push origin main

# Monitor in GitHub → Actions
```

### Rollback

If something goes wrong, you can quickly rollback to a previous version:

```bash
# List previous task definitions
aws ecs list-task-definitions \
  --family-prefix user-app-backend \
  --region ap-south-1

# Update service to use a previous task definition
aws ecs update-service \
  --cluster user-app-cluster \
  --service user-app-backend-service \
  --task-definition user-app-backend:2 \
  --region ap-south-1
```

---

## Troubleshooting

### Issue: Infrastructure script fails

**Solution:**
```bash
# Check AWS CLI configuration
aws sts get-caller-identity

# Try running just one step
bash aws/setup-complete-infrastructure.sh 2>&1 | tee setup.log

# Check the log for errors
grep ERROR setup.log
```

### Issue: GitHub Actions fails on "Push to ECR"

**Solution:**
```bash
# Verify ECR repositories exist
aws ecr describe-repositories --region ap-south-1

# Verify GitHub secrets are set
# GitHub → Settings → Secrets and variables → Actions

# Check credentials
aws sts get-caller-identity
```

### Issue: ECS tasks won't start

**Solution:**
```bash
# Check task logs
aws logs tail /ecs/user-app-backend --region ap-south-1

# Check service status
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service \
  --region ap-south-1 \
  --query 'services[0].events[0:3]'

# Common issues:
# 1. Insufficient memory - increase task definition memory
# 2. Image not found - verify image pushed to ECR
# 3. Database connection - verify RDS security group
```

### Issue: ALB shows unhealthy targets

**Solution:**
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN> \
  --region ap-south-1

# Common issues:
# 1. Health check path incorrect
# 2. Security group blocking traffic
# 3. Application not responding on health check port
```

### Issue: Can't connect to RDS from ECS

**Solution:**
```bash
# Verify RDS is in private subnet
aws rds describe-db-instances \
  --db-instance-identifier user-app-db \
  --region ap-south-1 \
  --query 'DBInstances[0].[DBInstanceIdentifier,Endpoint.Address,DBSubnetGroup.DBSubnetGroupName]'

# Verify security group allows ECS access
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --region ap-south-1 \
  --query 'SecurityGroups[0].IpPermissions'

# Test from ECS task
aws ecs execute-command \
  --cluster user-app-cluster \
  --task <TASK_ID> \
  --container user-app-backend \
  --interactive \
  --command "/bin/sh"

# Inside container:
# mysql -h myappdb.c9oq2ky8kisq.ap-south-1.rds.amazonaws.com -u admin -p
```

---

## Monitoring and Maintenance

### View Application Logs

```bash
# Backend logs (last 50 entries)
aws logs tail /ecs/user-app-backend --max-items 50 --region ap-south-1

# Frontend logs
aws logs tail /ecs/user-app-frontend --max-items 50 --region ap-south-1

# Follow logs in real-time
aws logs tail /ecs/user-app-backend --follow --region ap-south-1
```

### Monitor Resource Usage

```bash
# Get task metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=user-app-backend-service \
                Name=ClusterName,Value=user-app-cluster \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 300 \
  --statistics Average,Maximum \
  --region ap-south-1
```

### Update Environment Variables

To update environment variables (e.g., database password):

```bash
# 1. Update task definition JSON
vim ecs/backend-task-definition.json

# 2. Register new revision
aws ecs register-task-definition \
  --cli-input-json file://ecs/backend-task-definition.json \
  --region ap-south-1

# 3. Update service to use new revision
aws ecs update-service \
  --cluster user-app-cluster \
  --service user-app-backend-service \
  --task-definition user-app-backend:2 \
  --force-new-deployment \
  --region ap-south-1
```

### Scale Services

```bash
# Scale backend to 3 replicas
aws ecs update-service \
  --cluster user-app-cluster \
  --service user-app-backend-service \
  --desired-count 3 \
  --region ap-south-1

# Scale frontend to 4 replicas
aws ecs update-service \
  --cluster user-app-cluster \
  --service user-app-frontend-service \
  --desired-count 4 \
  --region ap-south-1
```

---

## Cost Optimization Tips

1. **Use Spot Instances** for non-critical workloads
   ```bash
   # Update service to use FARGATE_SPOT
   aws ecs update-service \
     --cluster user-app-cluster \
     --service user-app-backend-service \
     --capacity-provider-strategy capacityProvider=FARGATE_SPOT,weight=1 \
     --region ap-south-1
   ```

2. **Auto-scale based on CPU/Memory**
   ```bash
   # Create scaling policy
   aws application-autoscaling register-scalable-target \
     --service-namespace ecs \
     --resource-id service/user-app-cluster/user-app-backend-service \
     --scalable-dimension ecs:service:DesiredCount \
     --min-capacity 1 \
     --max-capacity 5 \
     --region ap-south-1
   ```

3. **Monitor costs in AWS Console**
   - AWS Console → Cost Explorer
   - Set up budget alerts

---

## Summary

You've successfully:
- ✅ Created a VPC with public and private subnets
- ✅ Set up an Application Load Balancer
- ✅ Launched an RDS MySQL database
- ✅ Created an ECS Fargate cluster
- ✅ Configured automated CI/CD with GitHub Actions
- ✅ Deployed your application

Now every `git push origin main` will automatically:
1. Build new Docker images
2. Push to ECR
3. Deploy to ECS
4. Monitor until stable

**Next Steps:**
- Monitor your application in CloudWatch
- Set up alerts for failures
- Configure auto-scaling
- Add HTTPS with ACM
- Set up data backups for RDS

---

## Quick Reference Commands

```bash
# Infrastructure
bash aws/setup-complete-infrastructure.sh      # Create all AWS resources
bash aws/deploy-ecs-services.sh               # Deploy services to ECS

# Monitoring
aws ecs list-services --cluster user-app-cluster --region ap-south-1
aws ecs describe-services --cluster user-app-cluster --services user-app-backend-service user-app-frontend-service --region ap-south-1
aws logs tail /ecs/user-app-backend --follow --region ap-south-1

# Deployment
git push origin main                          # Triggers GitHub Actions

# Debugging
aws ecs describe-task-definition --task-definition user-app-backend --region ap-south-1
aws elbv2 describe-target-health --target-group-arn <ARN> --region ap-south-1
```

---

**Status**: ✅ **PRODUCTION READY**

Your application is now running on AWS ECS with automatic deployment! 🚀
