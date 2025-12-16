# AWS Infrastructure Guide for User App

This guide provides step-by-step instructions for setting up AWS resources for the User App deployment.

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured
- GitHub repository created
- GitHub CLI installed (optional, for secret management)

## Architecture Overview

```
Internet Users
      ↓
  Internet Gateway
      ↓
Application Load Balancer (ALB) - Public Subnets
      ↓
Private VPC (10.0.0.0/16)
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24) - ALB, NAT Gateway
├── Private Subnets (10.0.10.0/24, 10.0.11.0/24)
│   ├── ECS Fargate Tasks (Frontend & Backend)
│   └── RDS MySQL Database
```

## Step 1: VPC & Networking Setup (Automated)

### Option A: Using Setup Script

```bash
export AWS_REGION=us-east-1
bash aws/setup-infrastructure.sh
```

### Option B: Manual Setup

#### 1.1 Create VPC

```bash
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region us-east-1 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=user-app-vpc}]'
```

Save the VPC ID: `VPC_ID=vpc-xxxxxxxxx`

#### 1.2 Enable DNS

```bash
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
```

#### 1.3 Create Internet Gateway

```bash
aws ec2 create-internet-gateway --region us-east-1 \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=user-app-igw}]'
```

Save the IGW ID: `IGW_ID=igw-xxxxxxxxx`

#### 1.4 Attach IGW to VPC

```bash
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region us-east-1
```

#### 1.5 Create Subnets

```bash
# Public Subnet 1 (us-east-1a)
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a --region us-east-1 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=user-app-public-1a}]'

# Public Subnet 2 (us-east-1b)
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1b --region us-east-1 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=user-app-public-1b}]'

# Private Subnet 1 (us-east-1a)
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.10.0/24 \
  --availability-zone us-east-1a --region us-east-1 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=user-app-private-1a}]'

# Private Subnet 2 (us-east-1b)
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.11.0/24 \
  --availability-zone us-east-1b --region us-east-1 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=user-app-private-1b}]'
```

Save subnet IDs:
```
PUB_SUBNET_1=subnet-xxxxxxxxx
PUB_SUBNET_2=subnet-yyyyyyyyy
PRIV_SUBNET_1=subnet-zzzzzzzzz
PRIV_SUBNET_2=subnet-aaaaaaaaa
```

#### 1.6 Create Route Tables

```bash
# Public Route Table
aws ec2 create-route-table --vpc-id $VPC_ID --region us-east-1 \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=user-app-public-rt}]'

# Private Route Table
aws ec2 create-route-table --vpc-id $VPC_ID --region us-east-1 \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=user-app-private-rt}]'
```

Save route table IDs:
```
PUBLIC_RT=rtb-xxxxxxxxx
PRIVATE_RT=rtb-yyyyyyyyy
```

#### 1.7 Add Routes and Associate Subnets

```bash
# Add public route to IGW
aws ec2 create-route --route-table-id $PUBLIC_RT --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID --region us-east-1

# Associate public subnets
aws ec2 associate-route-table --subnet-id $PUB_SUBNET_1 --route-table-id $PUBLIC_RT --region us-east-1
aws ec2 associate-route-table --subnet-id $PUB_SUBNET_2 --route-table-id $PUBLIC_RT --region us-east-1

# Associate private subnets
aws ec2 associate-route-table --subnet-id $PRIV_SUBNET_1 --route-table-id $PRIVATE_RT --region us-east-1
aws ec2 associate-route-table --subnet-id $PRIV_SUBNET_2 --route-table-id $PRIVATE_RT --region us-east-1
```

## Step 2: Security Groups

### 2.1 ALB Security Group

```bash
ALB_SG=$(aws ec2 create-security-group \
  --group-name user-app-alb-sg \
  --description "Security group for ALB" \
  --vpc-id $VPC_ID --region us-east-1 \
  --query 'GroupId' --output text)

# Allow HTTP
aws ec2 authorize-security-group-ingress --group-id $ALB_SG \
  --protocol tcp --port 80 --cidr 0.0.0.0/0 --region us-east-1

# Allow HTTPS (for production)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG \
  --protocol tcp --port 443 --cidr 0.0.0.0/0 --region us-east-1
```

### 2.2 ECS Security Group

```bash
ECS_SG=$(aws ec2 create-security-group \
  --group-name user-app-ecs-sg \
  --description "Security group for ECS tasks" \
  --vpc-id $VPC_ID --region us-east-1 \
  --query 'GroupId' --output text)

# Allow traffic from ALB
aws ec2 authorize-security-group-ingress --group-id $ECS_SG \
  --protocol tcp --port 0-65535 --source-group $ALB_SG --region us-east-1
```

### 2.3 RDS Security Group

```bash
RDS_SG=$(aws ec2 create-security-group \
  --group-name user-app-rds-sg \
  --description "Security group for RDS" \
  --vpc-id $VPC_ID --region us-east-1 \
  --query 'GroupId' --output text)

# Allow MySQL from ECS
aws ec2 authorize-security-group-ingress --group-id $RDS_SG \
  --protocol tcp --port 3306 --source-group $ECS_SG --region us-east-1
```

## Step 3: RDS MySQL Setup

### 3.1 Create DB Subnet Group

```bash
aws rds create-db-subnet-group \
  --db-subnet-group-name user-app-db-subnet \
  --db-subnet-group-description "Subnet group for User App RDS" \
  --subnet-ids $PRIV_SUBNET_1 $PRIV_SUBNET_2 \
  --region us-east-1
```

### 3.2 Store DB Password in Secrets Manager

```bash
DB_PASSWORD="YourSecurePassword123!"

aws secretsmanager create-secret \
  --name user-app/db-password \
  --description "User App RDS Database Password" \
  --secret-string "{\"username\":\"admin\",\"password\":\"$DB_PASSWORD\"}" \
  --region us-east-1
```

### 3.3 Create RDS Instance

```bash
aws rds create-db-instance \
  --db-instance-identifier user-app-db \
  --db-instance-class db.t3.micro \
  --engine mysql \
  --engine-version 8.0 \
  --master-username admin \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 100 \
  --db-subnet-group-name user-app-db-subnet \
  --vpc-security-group-ids $RDS_SG \
  --multi-az \
  --publicly-accessible false \
  --storage-encrypted true \
  --enable-cloudwatch-logs-exports error general slowquery \
  --backup-retention-period 7 \
  --region us-east-1
```

**Note:** This will take 5-10 minutes to complete.

### 3.4 Get RDS Endpoint

```bash
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier user-app-db \
  --region us-east-1 \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "RDS Endpoint: $RDS_ENDPOINT"
```

## Step 4: ECR Repositories

```bash
aws ecr create-repository --repository-name user-app-backend --region us-east-1
aws ecr create-repository --repository-name user-app-frontend --region us-east-1
```

## Step 5: ECS Cluster and CloudWatch Logs

```bash
# Create ECS Cluster
aws ecs create-cluster --cluster-name user-app-cluster --region us-east-1

# Create CloudWatch Log Groups
aws logs create-log-group --log-group-name /ecs/user-app-backend --region us-east-1
aws logs create-log-group --log-group-name /ecs/user-app-frontend --region us-east-1
```

## Step 6: IAM Roles

### 6.1 Create ECS Task Execution Role

```bash
# Create trust policy
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
EXEC_ROLE_ARN=$(aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document file://trust-policy.json \
  --region us-east-1 \
  --query 'Role.Arn' \
  --output text)

# Attach policies
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess
```

### 6.2 Create ECS Task Role

```bash
# Create task role
TASK_ROLE_ARN=$(aws iam create-role \
  --role-name ecsTaskRole \
  --assume-role-policy-document file://trust-policy.json \
  --region us-east-1 \
  --query 'Role.Arn' \
  --output text)

# Add inline policy for Secrets Manager
cat > task-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:user-app/*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name ecsTaskRole \
  --policy-name SecretManagerAccess \
  --policy-document file://task-policy.json
```

## Step 7: Application Load Balancer

### 7.1 Create ALB

```bash
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name user-app-alb \
  --subnets $PUB_SUBNET_1 $PUB_SUBNET_2 \
  --security-groups $ALB_SG \
  --scheme internet-facing \
  --type application \
  --region us-east-1 \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

# Get ALB DNS
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --region us-east-1 \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "ALB DNS: $ALB_DNS"
```

### 7.2 Create Target Groups

```bash
# Frontend Target Group
FRONTEND_TG=$(aws elbv2 create-target-group \
  --name user-app-frontend-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --target-type ip \
  --health-check-enabled \
  --health-check-protocol HTTP \
  --health-check-path / \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --region us-east-1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Backend Target Group
BACKEND_TG=$(aws elbv2 create-target-group \
  --name user-app-backend-tg \
  --protocol HTTP \
  --port 5000 \
  --vpc-id $VPC_ID \
  --target-type ip \
  --health-check-enabled \
  --health-check-protocol HTTP \
  --health-check-path /api/health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --region us-east-1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)
```

### 7.3 Create ALB Listener

```bash
# Default listener (frontend)
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG \
  --region us-east-1
```

## Step 8: ECS Task Definitions

Update `aws/backend-task-definition.json` and `aws/frontend-task-definition.json` with your values:

```bash
# Replace placeholders
sed -i "s/ACCOUNT_ID/$(aws sts get-caller-identity --query Account --output text)/g" aws/backend-task-definition.json
sed -i "s/REGION/us-east-1/g" aws/backend-task-definition.json
sed -i "s/RDS_ENDPOINT/$RDS_ENDPOINT/g" aws/backend-task-definition.json

# Register task definitions
aws ecs register-task-definition \
  --cli-input-json file://aws/backend-task-definition.json \
  --region us-east-1

aws ecs register-task-definition \
  --cli-input-json file://aws/frontend-task-definition.json \
  --region us-east-1
```

## Step 9: ECS Services

### 9.1 Create Backend Service

```bash
aws ecs create-service \
  --cluster user-app-cluster \
  --service-name user-app-backend-service \
  --task-definition user-app-backend:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$PRIV_SUBNET_1,$PRIV_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=$BACKEND_TG,containerName=user-app-backend,containerPort=5000" \
  --region us-east-1
```

### 9.2 Create Frontend Service

```bash
aws ecs create-service \
  --cluster user-app-cluster \
  --service-name user-app-frontend-service \
  --task-definition user-app-frontend:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$PRIV_SUBNET_1,$PRIV_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=$FRONTEND_TG,containerName=user-app-frontend,containerPort=80" \
  --region us-east-1
```

## Step 10: GitHub CI/CD Setup

### 10.1 Create OIDC Provider (for GitHub Actions)

```bash
# Get thumbprint
THUMBPRINT=$(curl -s https://token.actions.githubusercontent.com/.well-known/openid-configuration | \
  jq -r '.jwks_uri | split("/")[2]' | \
  openssl s_client -servername token.actions.githubusercontent.com -connect {} 2>/dev/null | \
  openssl x509 -fingerprint -noout | sed 's/://g' | awk '{print substr($2,9)}')

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list $THUMBPRINT \
  --region us-east-1
```

### 10.2 Create GitHub Actions IAM Role

```bash
cat > github-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:GITHUB_ORG/GITHUB_REPO:*"
        }
      }
    }
  ]
}
EOF

# Replace placeholders
sed -i "s/ACCOUNT_ID/$(aws sts get-caller-identity --query Account --output text)/g" github-trust-policy.json
sed -i "s/GITHUB_ORG/your-username/g" github-trust-policy.json
sed -i "s/GITHUB_REPO/user-app/g" github-trust-policy.json

# Create role
GITHUB_ROLE_ARN=$(aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://github-trust-policy.json \
  --region us-east-1 \
  --query 'Role.Arn' \
  --output text)

# Attach policy
cat > github-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:DescribeTasks",
        "ecs:ListTasks",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsPolicy \
  --policy-document file://github-policy.json
```

### 10.3 Configure GitHub Secrets

```bash
export GITHUB_REPO="your-username/user-app"
export AWS_ROLE_TO_ASSUME="$GITHUB_ROLE_ARN"

bash aws/setup-github-secrets.sh
```

Or manually in GitHub:
1. Go to repository Settings → Secrets and variables → Actions
2. Add:
   - `AWS_ROLE_TO_ASSUME`: `arn:aws:iam::ACCOUNT_ID:role/GitHubActionsRole`
   - `AWS_REGION`: `us-east-1`

## Monitoring & Logs

```bash
# View ECS service logs
aws logs tail /ecs/user-app-backend --follow --region us-east-1
aws logs tail /ecs/user-app-frontend --follow --region us-east-1

# Check ECS service status
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region us-east-1
```

## Cleanup

To delete all resources:

```bash
# Delete ECS services
aws ecs delete-service --cluster user-app-cluster --service user-app-backend-service --force
aws ecs delete-service --cluster user-app-cluster --service user-app-frontend-service --force

# Delete ECS cluster
aws ecs delete-cluster --cluster user-app-cluster

# Delete RDS instance
aws rds delete-db-instance --db-instance-identifier user-app-db --skip-final-snapshot

# Delete ALB
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN

# Delete target groups
aws elbv2 delete-target-group --target-group-arn $FRONTEND_TG
aws elbv2 delete-target-group --target-group-arn $BACKEND_TG

# Delete VPC and related resources
aws ec2 detach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
aws ec2 delete-vpc --vpc-id $VPC_ID
```

## Troubleshooting

### ECS Tasks not starting
- Check CloudWatch logs
- Verify IAM role permissions
- Check security group rules
- Verify RDS connectivity

### ALB returning 503
- Check target health in target groups
- Verify security group allows ALB to ECS traffic
- Check ECS task logs

### Database connection errors
- Verify RDS security group allows traffic from ECS
- Check RDS is in running state
- Verify database credentials in Secrets Manager

## Cost Optimization

- Use Fargate Spot for non-production
- Set auto-scaling policies
- Use t3 instances for development
- Delete unused resources
- Monitor CloudWatch billing

---

For questions or issues, see the main README.md
