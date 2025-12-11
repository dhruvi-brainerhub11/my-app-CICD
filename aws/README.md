# 🚀 AWS ECS Complete Automation Setup

Automated deployment of user-app to AWS ECS Fargate with GitHub Actions CI/CD.

## 📋 Overview

This project provides complete automation for deploying a Node.js/React application to AWS using:

- **Infrastructure**: VPC, ALB, RDS, ECS Fargate
- **Automation**: Bash scripts for complete setup
- **CI/CD**: GitHub Actions for automatic deployment
- **Monitoring**: CloudWatch logs and metrics

## 🎯 Features

✅ **Complete Infrastructure as Code**
- VPC with public and private subnets
- NAT Gateway for private subnet outbound
- Application Load Balancer with routing rules
- RDS MySQL database (encrypted, backed up)
- ECS Fargate cluster with auto-scaling ready

✅ **Automated Deployment**
- One-command infrastructure setup
- One-command ECS deployment
- Complete GitHub Actions CI/CD
- Automatic rollback on failure

✅ **Security**
- Databases in private subnets
- Security groups with least privilege
- IAM roles with minimal permissions
- Encrypted database connections

✅ **Monitoring**
- CloudWatch log groups
- Application health checks
- ALB target health monitoring
- Task metrics and monitoring

## 📁 File Structure

```
aws/
├── setup-complete-infrastructure.sh    # Create all AWS resources
├── deploy-ecs-services.sh              # Deploy services to ECS
├── complete-deployment.sh              # Full build + push + deploy
├── AWS-CLI-COMMANDS.md                 # Reference of all AWS CLI commands
└── README.md                           # This file

ecs/
├── backend-task-definition.json        # Backend ECS task definition
└── frontend-task-definition.json       # Frontend ECS task definition

.github/workflows/
├── build-push-ecr.yml                  # Build and push to ECR
└── deploy-ecs.yml                      # Deploy to ECS (manual)
```

## 🚀 Quick Start (3 Steps)

### Step 1: Create AWS Infrastructure (10-15 minutes)

```bash
cd /home/admin01/Dhruvi/user-app
chmod +x aws/*.sh
bash aws/setup-complete-infrastructure.sh
```

This creates:
- VPC with public/private subnets
- Internet Gateway and NAT Gateway
- Application Load Balancer
- RDS MySQL Database
- ECS Cluster
- CloudWatch Log Groups
- ECR Repositories
- IAM Roles

**Output**: `aws-infrastructure-config.json` with all resource IDs

### Step 2: Set GitHub Secrets

Add to GitHub Repository → Settings → Secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` = `ap-south-1`

### Step 3: Deploy

```bash
# Push code to trigger GitHub Actions
git push origin main

# Or manually deploy
bash aws/deploy-ecs-services.sh
```

## 📖 Detailed Guide

See [AWS-ECS-DEPLOYMENT-GUIDE.md](AWS-ECS-DEPLOYMENT-GUIDE.md) for:
- Step-by-step setup instructions
- Troubleshooting guide
- Monitoring and maintenance
- Cost optimization tips
- AWS CLI command reference

## 🔧 Scripts Overview

### setup-complete-infrastructure.sh

**Purpose**: Create all AWS infrastructure resources

**Usage**:
```bash
bash aws/setup-complete-infrastructure.sh
```

**What it does**:
1. Creates VPC (10.0.0.0/16)
2. Creates 4 subnets (2 public, 2 private)
3. Sets up Internet Gateway and NAT Gateway
4. Configures route tables
5. Creates security groups
6. Creates Application Load Balancer with target groups
7. Creates RDS MySQL database
8. Creates ECS Fargate cluster
9. Creates CloudWatch log groups
10. Creates ECR repositories
11. Creates IAM roles and policies
12. Saves configuration to JSON file

**Time**: ~15 minutes (RDS takes longest)

**Output**:
- `aws-infrastructure-config.json` - Contains all resource IDs and endpoints

### deploy-ecs-services.sh

**Purpose**: Register task definitions and create/update ECS services

**Usage**:
```bash
bash aws/deploy-ecs-services.sh [backend-image] [frontend-image]
```

**Examples**:
```bash
# Use latest images from ECR
bash aws/deploy-ecs-services.sh

# Use specific image versions
bash aws/deploy-ecs-services.sh \
  619576923139.dkr.ecr.ap-south-1.amazonaws.com/user-app-backend:v1.0 \
  619576923139.dkr.ecr.ap-south-1.amazonaws.com/user-app-frontend:v1.0
```

**What it does**:
1. Registers backend task definition
2. Registers frontend task definition
3. Creates or updates ECS services
4. Monitors deployment until stable
5. Reports status and ALB DNS

**Time**: ~5 minutes

### complete-deployment.sh

**Purpose**: Full pipeline - build, push to ECR, and deploy to ECS

**Usage**:
```bash
bash aws/complete-deployment.sh
```

**What it does**:
1. Checks prerequisites (Docker, AWS CLI, git)
2. Clones/updates repository
3. Builds Docker images
4. Logs into ECR
5. Pushes images to ECR
6. Registers task definitions
7. Creates/updates ECS services
8. Monitors deployment
9. Verifies application is running

**Time**: ~15 minutes

## 🔄 CI/CD Workflow

### Manual: GitHub Actions on Push

```bash
git push origin main
```

GitHub Actions automatically:
1. Builds Docker images
2. Pushes to ECR
3. Updates ECS task definitions
4. Deploys to ECS services
5. Waits for stability

**Time**: ~10 minutes

### Manual: Local Deployment

```bash
bash aws/complete-deployment.sh
```

Equivalent to GitHub Actions but runs locally.

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet (0.0.0.0/0)                    │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
        ┌────────────────────────────────────┐
        │  Application Load Balancer (ALB)   │
        │  DNS: user-app-alb-*.elb.amazonaws.com
        │  - HTTP (80)                       │
        │  - /api/* → Backend (port 5000)   │
        │  - /* → Frontend (port 80)         │
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
      │                                     │
      │  Backend Tasks (2 replicas)         │
      │  ├─ user-app-backend:v1.0          │
      │  ├─ Port: 5000                     │
      │  └─ Memory: 2GB, CPU: 512          │
      │                                     │
      │  Frontend Tasks (2 replicas)        │
      │  ├─ user-app-frontend:v1.0         │
      │  ├─ Port: 80                       │
      │  └─ Memory: 1GB, CPU: 512          │
      └──────┬──────────────────────┬──────┘
             │                      │
             └──────────┬───────────┘
                        │
                        ▼
              ┌──────────────────┐
              │  RDS MySQL       │
              │  (Private Subnet)│
              │  myappdb         │
              │  db.t3.micro     │
              └──────────────────┘
```

## 📊 Configuration Files

### aws-infrastructure-config.json

Generated after running `setup-complete-infrastructure.sh`

```json
{
  "project_name": "user-app",
  "aws_region": "ap-south-1",
  "aws_account_id": "619576923139",
  "vpc": {
    "id": "vpc-0123456789abcdef0",
    "cidr": "10.0.0.0/16"
  },
  "subnets": {
    "public_1": { "id": "subnet-...", "az": "ap-south-1a" },
    "public_2": { "id": "subnet-...", "az": "ap-south-1b" },
    "private_1": { "id": "subnet-...", "az": "ap-south-1a" },
    "private_2": { "id": "subnet-...", "az": "ap-south-1b" }
  },
  "load_balancer": {
    "arn": "arn:aws:elasticloadbalancing:...",
    "dns": "user-app-alb-508171731.ap-south-1.elb.amazonaws.com"
  },
  "rds": {
    "endpoint": "user-app-db.c9oq2ky8kisq.ap-south-1.rds.amazonaws.com",
    "db_name": "myappdb",
    "db_user": "admin"
  },
  "ecs": {
    "cluster_name": "user-app-cluster"
  }
}
```

## 🐛 Troubleshooting

### Infrastructure setup fails

```bash
# Check AWS CLI is configured
aws sts get-caller-identity

# Run with detailed output
bash aws/setup-complete-infrastructure.sh 2>&1 | tee setup.log

# Check specific errors
grep ERROR setup.log
```

### GitHub Actions fails

1. **Login to ECR fails**: Check AWS credentials in GitHub Secrets
2. **Push to ECR fails**: Verify ECR repositories exist
3. **Deploy fails**: Check ECS cluster exists and has capacity
4. **Tasks won't start**: Check task definition image URI is correct

### ECS tasks won't start

```bash
# Check logs
aws logs tail /ecs/user-app-backend --follow --region ap-south-1

# Check task status
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service \
  --region ap-south-1

# Check events
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service \
  --region ap-south-1 \
  --query 'services[0].events[0:3]'
```

### ALB targets are unhealthy

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN> \
  --region ap-south-1

# Common issues:
# 1. Health check path incorrect
# 2. Security group blocking traffic
# 3. Application not responding on health check port
```

## 📈 Monitoring

### View Application Logs

```bash
# Backend
aws logs tail /ecs/user-app-backend --follow --region ap-south-1

# Frontend
aws logs tail /ecs/user-app-frontend --follow --region ap-south-1
```

### Check Service Status

```bash
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1 \
  --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
  --output table
```

### Monitor CloudWatch Metrics

- CPU Utilization
- Memory Utilization
- Network In/Out
- ALB Request Count
- Target Response Time

## 💰 Cost Estimation

**Typical Monthly Cost** (with default configuration):

| Service | Configuration | Cost |
|---------|---|---|
| **ECS Fargate** | 4 tasks (2 x 512 CPU, 2GB) | $50-70 |
| **ALB** | 1 ALB + LCU | $20-30 |
| **RDS** | db.t3.micro + 20GB storage | $20-30 |
| **NAT Gateway** | 1 NAT + data transfer | $30-50 |
| **ECR** | Repository storage + bandwidth | $5-10 |
| **CloudWatch** | Logs retention (7 days) | $5-10 |
| **Total** | | **$130-200/month** |

**Cost Optimization**:
- Use FARGATE_SPOT for non-critical workloads (50% cheaper)
- Set auto-scaling policies
- Enable RDS reserved instances
- Monitor with AWS Cost Explorer

## 🔐 Security

✅ **Network Security**
- VPC with private subnets for databases
- NAT Gateway for private subnet internet access
- Security groups with least privilege

✅ **Data Security**
- RDS encryption at rest
- SSL/TLS for data in transit
- Secrets management with AWS Secrets Manager

✅ **Access Control**
- IAM roles with minimal permissions
- Task execution role separate from task role
- No hardcoded credentials

## 🔄 Deployment Strategies

### Blue-Green Deployment

```bash
# Current production: Blue
# New version: Green

# Deploy new version as separate service
aws elbv2 modify-listener --listener-arn <ARN> \
  --default-actions Type=forward,TargetGroupArn=<NEW_TG>

# Immediate cutover, easy rollback
```

### Canary Deployment

```bash
# Gradually shift traffic
aws elbv2 modify-rule --rule-arn <ARN> \
  --conditions Field=path-pattern,Values=/api/* \
  --actions Type=forward,ForwardConfig={
    TargetGroups=[
      {TargetGroupArn=<NEW_TG>,Weight=10},
      {TargetGroupArn=<OLD_TG>,Weight=90}
    ]
  }
```

### Rolling Deployment (Default)

- Maximum 200% of desired count
- Minimum 100% healthy
- Automatic in GitHub Actions

## 📚 Additional Resources

- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/best_practices.html)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)

## 📝 Next Steps

1. ✅ Run infrastructure setup
2. ✅ Add GitHub Secrets
3. ✅ Push code to trigger deployment
4. ✅ Monitor CloudWatch logs
5. ✅ Set up alerts for failures
6. ✅ Configure backup policies
7. ✅ Set up auto-scaling
8. ✅ Add HTTPS with ACM

## 📞 Support

For issues:
1. Check [AWS-ECS-DEPLOYMENT-GUIDE.md](AWS-ECS-DEPLOYMENT-GUIDE.md) troubleshooting section
2. Check [AWS-CLI-COMMANDS.md](AWS-CLI-COMMANDS.md) for command reference
3. Review CloudWatch logs
4. Check GitHub Actions logs
5. Check ECS service events

---

**Status**: ✅ **PRODUCTION READY**

Your application is ready to deploy to AWS ECS with complete automation! 🚀
