# 📋 AWS CLI Command Reference

Complete list of AWS CLI commands used in the deployment automation scripts.

---

## VPC and Network Commands

### Create VPC
```bash
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=user-app-vpc}]' \
  --region ap-south-1
```

### Create Public Subnet
```bash
aws ec2 create-subnet \
  --vpc-id vpc-123456 \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ap-south-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=user-app-public-subnet-1a}]' \
  --region ap-south-1
```

### Create Private Subnet
```bash
aws ec2 create-subnet \
  --vpc-id vpc-123456 \
  --cidr-block 10.0.10.0/24 \
  --availability-zone ap-south-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=user-app-private-subnet-1a}]' \
  --region ap-south-1
```

### Create Internet Gateway
```bash
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=user-app-igw}]' \
  --region ap-south-1
```

### Attach Internet Gateway to VPC
```bash
aws ec2 attach-internet-gateway \
  --internet-gateway-id igw-123456 \
  --vpc-id vpc-123456 \
  --region ap-south-1
```

### Create Route Table
```bash
aws ec2 create-route-table \
  --vpc-id vpc-123456 \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=user-app-public-rt}]' \
  --region ap-south-1
```

### Create Route to Internet Gateway
```bash
aws ec2 create-route \
  --route-table-id rtb-123456 \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id igw-123456 \
  --region ap-south-1
```

### Allocate Elastic IP for NAT
```bash
aws ec2 allocate-address \
  --domain vpc \
  --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=user-app-nat-eip}]' \
  --region ap-south-1
```

### Create NAT Gateway
```bash
aws ec2 create-nat-gateway \
  --subnet-id subnet-123456 \
  --allocation-id eipalloc-123456 \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=user-app-nat}]' \
  --region ap-south-1
```

### Create Route to NAT Gateway
```bash
aws ec2 create-route \
  --route-table-id rtb-123456 \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id nat-123456 \
  --region ap-south-1
```

---

## Security Group Commands

### Create Security Group
```bash
aws ec2 create-security-group \
  --group-name user-app-alb-sg \
  --description "Security group for ALB" \
  --vpc-id vpc-123456 \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=user-app-alb-sg}]' \
  --region ap-south-1
```

### Add Inbound Rule (HTTP)
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-123456 \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region ap-south-1
```

### Add Inbound Rule (HTTPS)
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-123456 \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region ap-south-1
```

### Add Inbound Rule (from Security Group)
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-123456 \
  --protocol tcp \
  --port 3306 \
  --source-group sg-987654 \
  --region ap-south-1
```

---

## Load Balancer Commands

### Create Application Load Balancer
```bash
aws elbv2 create-load-balancer \
  --name user-app-alb \
  --subnets subnet-123456 subnet-789012 \
  --security-groups sg-123456 \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --tags Key=Name,Value=user-app-alb \
  --region ap-south-1
```

### Create Target Group
```bash
aws elbv2 create-target-group \
  --name user-app-backend-tg \
  --protocol HTTP \
  --port 5000 \
  --vpc-id vpc-123456 \
  --target-type ip \
  --health-check-enabled \
  --health-check-protocol HTTP \
  --health-check-path /api/health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --matcher HttpCode=200 \
  --tags Key=Name,Value=user-app-backend-tg \
  --region ap-south-1
```

### Create Listener
```bash
aws elbv2 create-listener \
  --load-balancer-arn arn:aws:elasticloadbalancing:ap-south-1:123456789012:loadbalancer/app/user-app-alb/1234567890abcdef \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:ap-south-1:123456789012:targetgroup/user-app-frontend-tg/1234567890abcdef \
  --region ap-south-1
```

### Create Listener Rule
```bash
aws elbv2 create-rule \
  --listener-arn arn:aws:elasticloadbalancing:ap-south-1:123456789012:listener/app/user-app-alb/1234567890abcdef/1234567890abcdef \
  --conditions Field=path-pattern,Values=/api/* \
  --priority 1 \
  --actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:ap-south-1:123456789012:targetgroup/user-app-backend-tg/1234567890abcdef \
  --region ap-south-1
```

### Describe Load Balancers
```bash
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?LoadBalancerName=='user-app-alb'].DNSName" \
  --region ap-south-1 \
  --output text
```

---

## RDS Commands

### Create DB Subnet Group
```bash
aws rds create-db-subnet-group \
  --db-subnet-group-name user-app-db-subnet-group \
  --db-subnet-group-description "Subnet group for RDS" \
  --subnet-ids subnet-123456 subnet-789012 \
  --tags Key=Name,Value=user-app-db-subnet-group \
  --region ap-south-1
```

### Create RDS Instance
```bash
aws rds create-db-instance \
  --db-instance-identifier user-app-db \
  --db-instance-class db.t3.micro \
  --engine mysql \
  --engine-version 8.0.35 \
  --master-username admin \
  --master-user-password Admin123456 \
  --allocated-storage 20 \
  --db-name myappdb \
  --vpc-security-group-ids sg-123456 \
  --db-subnet-group-name user-app-db-subnet-group \
  --multi-az false \
  --publicly-accessible false \
  --storage-type gp2 \
  --tags Key=Name,Value=user-app-db Key=Environment,Value=production \
  --region ap-south-1
```

### Wait for RDS to be Available
```bash
aws rds wait db-instance-available \
  --db-instance-identifier user-app-db \
  --region ap-south-1
```

### Describe RDS Instance
```bash
aws rds describe-db-instances \
  --db-instance-identifier user-app-db \
  --region ap-south-1 \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

---

## ECS Commands

### Create ECS Cluster
```bash
aws ecs create-cluster \
  --cluster-name user-app-cluster \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1,base=1 \
  --tags key=Name,value=user-app-cluster key=Environment,value=production \
  --region ap-south-1
```

### Register Task Definition
```bash
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json \
  --region ap-south-1
```

### Create Service
```bash
aws ecs create-service \
  --cluster user-app-cluster \
  --service-name user-app-backend-service \
  --task-definition user-app-backend:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --platform-version LATEST \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-123456,subnet-789012],securityGroups=[sg-123456],assignPublicIp=DISABLED}" \
  --load-balancers targetGroupArn=arn:aws:elasticloadbalancing:ap-south-1:123456789012:targetgroup/user-app-backend-tg/1234567890abcdef,containerName=user-app-backend,containerPort=5000 \
  --deployment-configuration maximumPercent=200,minimumHealthyPercent=100 \
  --enable-ecs-managed-tags \
  --tags key=Name,value=user-app-backend-service key=Environment,value=production \
  --region ap-south-1
```

### Update Service
```bash
aws ecs update-service \
  --cluster user-app-cluster \
  --service user-app-backend-service \
  --task-definition user-app-backend:2 \
  --force-new-deployment \
  --region ap-south-1
```

### Describe Services
```bash
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1
```

### List Tasks
```bash
aws ecs list-tasks \
  --cluster user-app-cluster \
  --service-name user-app-backend-service \
  --region ap-south-1
```

### Describe Tasks
```bash
aws ecs describe-tasks \
  --cluster user-app-cluster \
  --tasks arn:aws:ecs:ap-south-1:123456789012:task/user-app-cluster/1234567890abcdef \
  --region ap-south-1
```

---

## CloudWatch Logs Commands

### Create Log Group
```bash
aws logs create-log-group \
  --log-group-name /ecs/user-app-backend \
  --region ap-south-1
```

### Put Retention Policy
```bash
aws logs put-retention-policy \
  --log-group-name /ecs/user-app-backend \
  --retention-in-days 7 \
  --region ap-south-1
```

### Tail Logs
```bash
aws logs tail /ecs/user-app-backend \
  --follow \
  --region ap-south-1
```

---

## ECR Commands

### Create Repository
```bash
aws ecr create-repository \
  --repository-name user-app-backend \
  --region ap-south-1
```

### Get Login Token
```bash
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin 123456789012.dkr.ecr.ap-south-1.amazonaws.com
```

### Describe Repositories
```bash
aws ecr describe-repositories \
  --repository-names user-app-backend \
  --region ap-south-1
```

---

## IAM Commands

### Create Role
```bash
aws iam create-role \
  --role-name user-app-ecs-task-execution-role \
  --assume-role-policy-document file://trust-policy.json
```

### Attach Policy
```bash
aws iam attach-role-policy \
  --role-name user-app-ecs-task-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

### Put Inline Policy
```bash
aws iam put-role-policy \
  --role-name user-app-ecs-task-execution-role \
  --policy-name ECSLogsPolicy \
  --policy-document file://logs-policy.json
```

---

## Monitoring Commands

### Get Metric Statistics
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=user-app-backend-service Name=ClusterName,Value=user-app-cluster \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 300 \
  --statistics Average,Maximum \
  --region ap-south-1
```

### Describe Target Health
```bash
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:ap-south-1:123456789012:targetgroup/user-app-backend-tg/1234567890abcdef \
  --region ap-south-1
```

---

## Useful Bash Scripts

### Get All IDs from Configuration
```bash
cat aws-infrastructure-config.json | jq '.'
```

### List all ECS Resources
```bash
echo "=== Clusters ===" && \
aws ecs list-clusters --region ap-south-1 --query 'clusterArns[]' && \
echo "=== Services ===" && \
aws ecs list-services --cluster user-app-cluster --region ap-south-1 --query 'serviceArns[]' && \
echo "=== Task Definitions ===" && \
aws ecs list-task-definitions --region ap-south-1 --query 'taskDefinitionArns[]'
```

### Get Service Status Summary
```bash
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1 \
  --query 'services[*].[serviceName,status,runningCount,desiredCount,deployments[0].status]' \
  --output table
```

### Get Task Logs
```bash
TASK_ID=$(aws ecs list-tasks --cluster user-app-cluster --service-name user-app-backend-service --region ap-south-1 --query 'taskArns[0]' --output text | rev | cut -d'/' -f1 | rev)
aws ecs describe-tasks --cluster user-app-cluster --tasks $TASK_ID --region ap-south-1
```

---

## Common Troubleshooting Commands

### Check if service is running
```bash
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service \
  --region ap-south-1 \
  --query 'services[0].[serviceName,status,desiredCount,runningCount,deployments[0].[status,desiredCount,runningCount]]'
```

### Check recent service events
```bash
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service \
  --region ap-south-1 \
  --query 'services[0].events[0:5]' \
  --output table
```

### Check ALB target health
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups --query "TargetGroups[?TargetGroupName=='user-app-backend-tg'].TargetGroupArn" --region ap-south-1 --output text) \
  --region ap-south-1 \
  --output table
```

---

## Cleanup Commands

### Delete all resources (when done with testing)
```bash
# Delete ECS Service
aws ecs delete-service \
  --cluster user-app-cluster \
  --service user-app-backend-service \
  --force \
  --region ap-south-1

# Delete ECS Cluster
aws ecs delete-cluster \
  --cluster user-app-cluster \
  --region ap-south-1

# Delete Load Balancer
aws elbv2 delete-load-balancer \
  --load-balancer-arn arn:aws:elasticloadbalancing:... \
  --region ap-south-1

# Delete RDS Instance
aws rds delete-db-instance \
  --db-instance-identifier user-app-db \
  --skip-final-snapshot \
  --region ap-south-1

# Delete VPC (and all associated resources)
aws ec2 delete-vpc \
  --vpc-id vpc-123456 \
  --region ap-south-1
```

---

## More Information

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/latest/userguide/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS RDS Documentation](https://docs.aws.amazon.com/rds/)
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
