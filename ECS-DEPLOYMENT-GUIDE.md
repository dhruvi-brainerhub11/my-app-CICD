# ECS Fargate Deployment Checklist

## Pre-Deployment Setup (One-time)

### AWS Infrastructure
- [x] Created ECS Cluster: `user-app-cluster`
- [x] Created RDS MySQL: `myappdb.c9oq2ky8kisq.ap-south-1.rds.amazonaws.com`
- [x] Created ALB: `my-app-alb-1553941597.ap-south-1.elb.amazonaws.com`
- [x] Created Task Definitions: `user-app-backend` and `user-app-frontend`
- [ ] Created ECR Repositories:
  - `user-app-backend`
  - `user-app-frontend`

### GitHub Configuration
- [x] Repository created: `my-app-CICD`
- [x] Code pushed to main branch
- [ ] GitHub Secrets configured:
  - `AWS_ACCESS_KEY_ID` → your AWS access key
  - `AWS_SECRET_ACCESS_KEY` → your AWS secret key
  - `AWS_REGION` → ap-south-1

### Environment Variables
- [x] `backend/.env.example` updated with RDS endpoint
- [x] `frontend/.env.example` updated with ALB URL
- [x] Task definitions updated with environment variables

---

## GitHub Secrets Setup

### How to Add Secrets

1. Go to: `https://github.com/dhruvi-brainerhub11/my-app-CICD/settings/secrets/actions`

2. Click **"New repository secret"** for each:

```
Name: AWS_ACCESS_KEY_ID
Value: your-aws-access-key-id

Name: AWS_SECRET_ACCESS_KEY
Value: your-aws-secret-access-key

Name: AWS_REGION
Value: ap-south-1
```

### Getting AWS Credentials

If you don't have credentials:

```bash
# Login to AWS Console
# Go to: IAM → Users → Your User → Security Credentials → Access Keys
# Create new access key
# Copy Access Key ID and Secret Access Key
```

---

## ECR Repository Creation

### Option 1: Using AWS Console
1. Go to ECR → Create Repository
2. Create two repositories:
   - `user-app-backend`
   - `user-app-frontend`
3. Note the repository URIs

### Option 2: Using AWS CLI
```bash
aws ecr create-repository \
  --repository-name user-app-backend \
  --region ap-south-1

aws ecr create-repository \
  --repository-name user-app-frontend \
  --region ap-south-1
```

---

## ECS Task Definitions Update

### Backend Task Definition

1. Go to AWS Console → ECS → Task Definitions → `user-app-backend`
2. Create new revision with these environment variables:

```json
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
```

### Frontend Task Definition

1. Go to AWS Console → ECS → Task Definitions → `user-app-frontend`
2. Create new revision with these environment variables:

```json
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
```

---

## ALB Configuration

### Backend Target Group

1. Go to EC2 → Target Groups → Create backend target group:
   - Name: `user-app-backend-tg`
   - Protocol: HTTP
   - Port: 5000
   - VPC: Your VPC

2. Register targets: ECS tasks in the backend service

3. Update ALB listener rule:
   - Path: `/api/*` → Target Group: `user-app-backend-tg`

### Frontend Target Group

1. Create frontend target group:
   - Name: `user-app-frontend-tg`
   - Protocol: HTTP
   - Port: 80
   - VPC: Your VPC

2. Register targets: ECS tasks in the frontend service

3. Update ALB listener rule:
   - Path: `/` → Target Group: `user-app-frontend-tg`

---

## Security Groups Configuration

### RDS Security Group

Allow inbound from ECS tasks:
- Type: MySQL/Aurora
- Protocol: TCP
- Port: 3306
- Source: ECS Task Security Group

### ECS Tasks Security Group

Allow inbound from ALB:
- Type: All traffic or HTTP/HTTPS
- Source: ALB Security Group

Allow outbound to RDS:
- Type: MySQL/Aurora
- Port: 3306
- Destination: RDS Security Group

### ALB Security Group

Allow inbound:
- Type: HTTP
- Port: 80
- Source: 0.0.0.0/0

- Type: HTTPS
- Port: 443
- Source: 0.0.0.0/0

---

## Deployment Steps

### Step 1: Push Code to GitHub
```bash
cd /home/admin01/Dhruvi/user-app
git add .
git commit -m "Deploy to ECS"
git push origin main
```

### Step 2: Monitor GitHub Actions Workflows

1. Go to: `https://github.com/dhruvi-brainerhub11/my-app-CICD/actions`

2. Two workflows will run:
   - **Build and Push to ECR**: Builds Docker images and pushes to ECR
   - **Deploy to ECS**: Updates task definitions and deploys to ECS Fargate

### Step 3: Verify Deployment

```bash
# Check services status
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1 \
  --query 'services[*].[serviceName,status,desiredCount,runningCount]' \
  --output table

# Check task status
aws ecs list-tasks \
  --cluster user-app-cluster \
  --region ap-south-1 \
  --query 'taskArns' \
  --output text

# Get task details
aws ecs describe-tasks \
  --cluster user-app-cluster \
  --tasks <task-arn> \
  --region ap-south-1
```

### Step 4: Access Application

1. Get ALB DNS name:
```bash
aws elbv2 describe-load-balancers \
  --names my-app-alb \
  --region ap-south-1 \
  --query 'LoadBalancers[0].DNSName'
```

2. Open browser:
   - Frontend: `http://my-app-alb-1553941597.ap-south-1.elb.amazonaws.com`
   - API Health: `http://my-app-alb-1553941597.ap-south-1.elb.amazonaws.com/api/health`

---

## Troubleshooting

### Workflow Fails to Build
- [ ] Check GitHub Secrets are set correctly
- [ ] Check ECR repositories exist
- [ ] Check AWS IAM user has permission: `ecr:*`, `ecs:*`

### ECS Service Won't Start
- [ ] Check task definition has latest image
- [ ] Check container logs: `aws logs get-log-events --log-group-name /ecs/user-app-backend --log-stream-name <stream-name>`
- [ ] Check security groups allow traffic
- [ ] Check ALB target group health

### Frontend Can't Connect to Backend
- [ ] Verify `REACT_APP_API_URL` is correct ALB endpoint
- [ ] Check ALB health checks passing
- [ ] Check backend service is running
- [ ] Check ALB listener rule for `/api/*` is correct

### RDS Connection Error
- [ ] Verify RDS security group allows inbound on 3306
- [ ] Verify `DB_HOST` is correct endpoint
- [ ] Verify `DB_PASSWORD` is correct
- [ ] Check ECS task can access RDS (security group rules)

---

## Useful AWS CLI Commands

```bash
# View logs
aws logs tail /ecs/user-app-backend --follow

# Restart service
aws ecs update-service \
  --cluster user-app-cluster \
  --service user-app-backend-service \
  --force-new-deployment \
  --region ap-south-1

# Get task definition
aws ecs describe-task-definition \
  --task-definition user-app-backend \
  --region ap-south-1 | jq '.taskDefinition.containerDefinitions[0].environment'

# Update task definition
aws ecs register-task-definition \
  --cli-input-json file://backend-task-definition.json \
  --region ap-south-1
```

---

## Summary

✅ **Ready for Deployment:**
- Code is pushed to GitHub
- GitHub Actions workflows are configured
- Environment variables are set
- AWS infrastructure is created

⏳ **Next Steps:**
1. Create ECR repositories (if not done)
2. Add GitHub Secrets (AWS credentials)
3. Update ECS Task Definitions with environment variables
4. Configure ALB target groups and routing
5. Configure security groups
6. Push code → Workflows run automatically → ECS updates → App deploys

---

## Important Notes

- **Commit SHA**: Each deployment uses the commit SHA as the image tag
- **Latest Tag**: Also pushed as `latest` for easy reference
- **Rolling Updates**: ECS will gradually replace old tasks with new ones
- **Health Checks**: Ensure ALB target groups have proper health check paths
- **Monitoring**: Use CloudWatch Logs to monitor application output

Good luck with your deployment! 🚀
