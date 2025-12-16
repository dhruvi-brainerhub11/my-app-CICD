#!/bin/bash

################################################################################
# 🗑️  DELETE ALL AWS RESOURCES
#
# This script deletes ALL resources created for this application:
# - ECS services and cluster
# - ALB and target groups
# - RDS database
# - VPC, subnets, gateways
# - Security groups
# - CloudWatch logs
# - ECR repositories
# - IAM roles
#
# Usage: bash aws/cleanup-all-resources.sh
################################################################################

set -e

REGION="ap-south-1"
echo "════════════════════════════════════════════════════════════════"
echo "🗑️  DELETING ALL AWS RESOURCES"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "⚠️  WARNING: This will DELETE everything!"
echo "    - ECS cluster, services, task definitions"
echo "    - ALB and target groups"
echo "    - RDS database (data will be lost!)"
echo "    - VPC, subnets, gateways"
echo "    - Security groups"
echo "    - ECR repositories"
echo "    - IAM roles"
echo ""
read -p "Type 'DELETE' to confirm: " confirm

if [ "$confirm" != "DELETE" ]; then
  echo "❌ Cancelled - No resources deleted"
  exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# 1. Delete ECS Services
echo "✓ Deleting ECS services..."
SERVICES=$(aws ecs list-services --cluster user-app-cluster --region $REGION --query 'serviceArns[]' --output text 2>/dev/null || echo "")
if [ ! -z "$SERVICES" ]; then
  for service in $SERVICES; do
    SERVICE_NAME=$(echo $service | rev | cut -d'/' -f1 | rev)
    echo "  Deleting service: $SERVICE_NAME"
    aws ecs delete-service \
      --cluster user-app-cluster \
      --service $SERVICE_NAME \
      --force \
      --region $REGION \
      --output text 2>/dev/null || echo "  ⚠️  Could not delete $SERVICE_NAME"
  done
fi
echo "✅ ECS services deleted"
echo ""

# 2. Delete ECS Cluster
echo "✓ Deleting ECS cluster..."
aws ecs delete-cluster \
  --cluster user-app-cluster \
  --region $REGION \
  --output text 2>/dev/null || echo "✅ ECS cluster deleted (or didn't exist)"
echo "✅ ECS cluster deleted"
echo ""

# 3. Delete ALB
echo "✓ Deleting Application Load Balancer..."
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?LoadBalancerName=='user-app-alb'].LoadBalancerArn" \
  --region $REGION \
  --output text 2>/dev/null || echo "")

if [ ! -z "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
  aws elbv2 delete-load-balancer \
    --load-balancer-arn $ALB_ARN \
    --region $REGION \
    --output text 2>/dev/null || echo "  ⚠️  Could not delete ALB"
  echo "✅ ALB deleted"
else
  echo "✅ ALB not found (skipping)"
fi
echo ""

# 4. Delete Target Groups
echo "✓ Deleting target groups..."
TG_ARNS=$(aws elbv2 describe-target-groups \
  --query "TargetGroups[?contains(TargetGroupName, 'user-app')].TargetGroupArn" \
  --region $REGION \
  --output text 2>/dev/null || echo "")

for tg_arn in $TG_ARNS; do
  if [ ! -z "$tg_arn" ] && [ "$tg_arn" != "None" ]; then
    aws elbv2 delete-target-group \
      --target-group-arn $tg_arn \
      --region $REGION \
      --output text 2>/dev/null || echo "  ⚠️  Could not delete target group"
  fi
done
echo "✅ Target groups deleted"
echo ""

# 5. Delete RDS Database
echo "✓ Deleting RDS database..."
aws rds delete-db-instance \
  --db-instance-identifier user-app-db \
  --skip-final-snapshot \
  --region $REGION \
  --output text 2>/dev/null || echo "✅ RDS not found (skipping)"
echo "✅ RDS database deleted"
echo ""

# 6. Delete NAT Gateway
echo "✓ Deleting NAT Gateway..."
NAT_ID=$(aws ec2 describe-nat-gateways \
  --filters Name=tag:Name,Values=user-app-nat-gateway \
  --region $REGION \
  --query 'NatGateways[0].NatGatewayId' \
  --output text 2>/dev/null || echo "None")

if [ "$NAT_ID" != "None" ] && [ ! -z "$NAT_ID" ]; then
  aws ec2 release-address \
    --allocation-id $(aws ec2 describe-addresses \
      --filters Name=association.nat-gateway-id,Values=$NAT_ID \
      --region $REGION \
      --query 'Addresses[0].AllocationId' \
      --output text) \
    --region $REGION \
    --output text 2>/dev/null || echo "  ⚠️  Could not release elastic IP"
  
  aws ec2 delete-nat-gateway \
    --nat-gateway-id $NAT_ID \
    --region $REGION \
    --output text 2>/dev/null || echo "  ⚠️  Could not delete NAT gateway"
fi
echo "✅ NAT Gateway deleted"
echo ""

# 7. Delete Internet Gateway
echo "✓ Deleting Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters Name=tag:Name,Values=user-app-igw \
  --region $REGION \
  --query 'InternetGateways[0].InternetGatewayId' \
  --output text 2>/dev/null || echo "None")

if [ "$IGW_ID" != "None" ] && [ ! -z "$IGW_ID" ]; then
  VPC_ID=$(aws ec2 describe-vpcs \
    --filters Name=cidr,Values=10.0.0.0/16 \
    --region $REGION \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || echo "None")
  
  if [ "$VPC_ID" != "None" ]; then
    aws ec2 detach-internet-gateway \
      --internet-gateway-id $IGW_ID \
      --vpc-id $VPC_ID \
      --region $REGION \
      --output text 2>/dev/null || echo "  ⚠️  Could not detach IGW"
  fi
  
  aws ec2 delete-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --region $REGION \
    --output text 2>/dev/null || echo "  ⚠️  Could not delete IGW"
fi
echo "✅ Internet Gateway deleted"
echo ""

# 8. Delete Route Tables
echo "✓ Deleting route tables..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=cidr,Values=10.0.0.0/16 \
  --region $REGION \
  --query 'Vpcs[0].VpcId' \
  --output text 2>/dev/null || echo "None")

if [ "$VPC_ID" != "None" ] && [ ! -z "$VPC_ID" ]; then
  RT_IDS=$(aws ec2 describe-route-tables \
    --filters Name=vpc-id,Values=$VPC_ID Name=tag:Name,Values=user-app-*-rt \
    --region $REGION \
    --query 'RouteTables[].RouteTableId' \
    --output text 2>/dev/null || echo "")
  
  for rt_id in $RT_IDS; do
    if [ ! -z "$rt_id" ] && [ "$rt_id" != "None" ]; then
      aws ec2 delete-route-table \
        --route-table-id $rt_id \
        --region $REGION \
        --output text 2>/dev/null || echo "  ⚠️  Could not delete route table"
    fi
  done
fi
echo "✅ Route tables deleted"
echo ""

# 9. Delete Subnets
echo "✓ Deleting subnets..."
if [ "$VPC_ID" != "None" ] && [ ! -z "$VPC_ID" ]; then
  SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters Name=vpc-id,Values=$VPC_ID \
    --region $REGION \
    --query 'Subnets[].SubnetId' \
    --output text 2>/dev/null || echo "")
  
  for subnet_id in $SUBNET_IDS; do
    if [ ! -z "$subnet_id" ] && [ "$subnet_id" != "None" ]; then
      aws ec2 delete-subnet \
        --subnet-id $subnet_id \
        --region $REGION \
        --output text 2>/dev/null || echo "  ⚠️  Could not delete subnet"
    fi
  done
fi
echo "✅ Subnets deleted"
echo ""

# 10. Delete Security Groups
echo "✓ Deleting security groups..."
if [ "$VPC_ID" != "None" ] && [ ! -z "$VPC_ID" ]; then
  SG_IDS=$(aws ec2 describe-security-groups \
    --filters Name=vpc-id,Values=$VPC_ID Name=tag:Name,Values=user-app-* \
    --region $REGION \
    --query 'SecurityGroups[].GroupId' \
    --output text 2>/dev/null || echo "")
  
  for sg_id in $SG_IDS; do
    if [ ! -z "$sg_id" ] && [ "$sg_id" != "None" ]; then
      aws ec2 delete-security-group \
        --group-id $sg_id \
        --region $REGION \
        --output text 2>/dev/null || echo "  ⚠️  Could not delete security group"
    fi
  done
fi
echo "✅ Security groups deleted"
echo ""

# 11. Delete VPC
echo "✓ Deleting VPC..."
if [ "$VPC_ID" != "None" ] && [ ! -z "$VPC_ID" ]; then
  aws ec2 delete-vpc \
    --vpc-id $VPC_ID \
    --region $REGION \
    --output text 2>/dev/null || echo "✅ VPC deleted (or has dependencies)"
fi
echo "✅ VPC deleted"
echo ""

# 12. Delete CloudWatch Log Groups
echo "✓ Deleting CloudWatch logs..."
LOG_GROUPS=$(/home/admin01/.local/bin/aws logs describe-log-groups \
  --log-group-name-prefix /ecs/user-app \
  --region $REGION \
  --query 'logGroups[].logGroupName' \
  --output text 2>/dev/null || echo "")

for log_group in $LOG_GROUPS; do
  if [ ! -z "$log_group" ] && [ "$log_group" != "None" ]; then
    aws logs delete-log-group \
      --log-group-name "$log_group" \
      --region $REGION \
      --output text 2>/dev/null || echo "  ⚠️  Could not delete log group: $log_group"
  fi
done
echo "✅ CloudWatch logs deleted"
echo ""

# 13. Delete ECR Repositories
echo "✓ Deleting ECR repositories..."
ECR_REPOS=$(aws ecr describe-repositories \
  --region $REGION \
  --query "repositories[?contains(repositoryName, 'user-app')].repositoryName" \
  --output text 2>/dev/null || echo "")

for repo in $ECR_REPOS; do
  if [ ! -z "$repo" ] && [ "$repo" != "None" ]; then
    aws ecr delete-repository \
      --repository-name $repo \
      --force \
      --region $REGION \
      --output text 2>/dev/null || echo "  ⚠️  Could not delete repository: $repo"
  fi
done
echo "✅ ECR repositories deleted"
echo ""

# 14. Delete IAM Roles
echo "✓ Deleting IAM roles..."
for role in ecsTaskRole ecsTaskExecutionRole; do
  # First detach policies
  POLICY_ARNS=$(aws iam list-role-policies \
    --role-name $role \
    --query 'PolicyNames' \
    --output text 2>/dev/null || echo "")
  
  for policy in $POLICY_ARNS; do
    aws iam delete-role-policy \
      --role-name $role \
      --policy-name $policy \
      --output text 2>/dev/null || echo "  ⚠️  Could not delete policy: $policy"
  done
  
  # Detach managed policies
  MANAGED_POLICIES=$(aws iam list-attached-role-policies \
    --role-name $role \
    --query 'AttachedPolicies[].PolicyArn' \
    --output text 2>/dev/null || echo "")
  
  for policy_arn in $MANAGED_POLICIES; do
    aws iam detach-role-policy \
      --role-name $role \
      --policy-arn $policy_arn \
      --output text 2>/dev/null || echo "  ⚠️  Could not detach policy"
  done
  
  # Delete role
  aws iam delete-role \
    --role-name $role \
    --output text 2>/dev/null || echo "  ⚠️  Could not delete role: $role"
done
echo "✅ IAM roles deleted"
echo ""

# 15. Delete configuration files
echo "✓ Cleaning up local files..."
rm -f aws-infrastructure-config.json
rm -f aws-config-backup.json
echo "✅ Local configuration files deleted"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "✅ ALL AWS RESOURCES DELETED!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Summary:"
echo "  ✅ ECS cluster and services deleted"
echo "  ✅ ALB and target groups deleted"
echo "  ✅ RDS database deleted"
echo "  ✅ VPC, subnets, gateways deleted"
echo "  ✅ Security groups deleted"
echo "  ✅ CloudWatch logs deleted"
echo "  ✅ ECR repositories deleted"
echo "  ✅ IAM roles deleted"
echo ""
echo "You can now:"
echo "1. Delete GitHub Secrets (if needed)"
echo "2. Set up AWS resources yourself"
echo "3. Use the automation scripts with your own configuration"
echo ""
