#!/bin/bash

# ECS Deployment Helper Script
# This script helps with common ECS deployment tasks

set -e

AWS_REGION="ap-south-1"
CLUSTER_NAME="user-app-cluster"
BACKEND_SERVICE="user-app-backend-service"
FRONTEND_SERVICE="user-app-frontend-service"
BACKEND_TASK_DEF="user-app-backend"
FRONTEND_TASK_DEF="user-app-frontend"
ECR_BACKEND_REPO="user-app-backend"
ECR_FRONTEND_REPO="user-app-frontend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_info() {
  echo -e "${YELLOW}ℹ $1${NC}"
}

# Commands
check_status() {
  print_header "Checking ECS Service Status"
  
  aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $BACKEND_SERVICE $FRONTEND_SERVICE \
    --region $AWS_REGION \
    --query 'services[*].[serviceName,status,desiredCount,runningCount]' \
    --output table
}

check_tasks() {
  print_header "Checking ECS Tasks"
  
  TASK_ARNS=$(aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --region $AWS_REGION \
    --query 'taskArns' \
    --output text)
  
  if [ -z "$TASK_ARNS" ]; then
    print_error "No tasks found"
    return
  fi
  
  aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARNS \
    --region $AWS_REGION \
    --query 'tasks[*].[taskArn,lastStatus,launchType]' \
    --output table
}

view_logs() {
  local SERVICE=$1
  print_header "Viewing Logs for $SERVICE"
  
  LOG_GROUP="/ecs/$SERVICE"
  
  # Get latest log stream
  STREAM=$(aws logs describe-log-streams \
    --log-group-name $LOG_GROUP \
    --region $AWS_REGION \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' \
    --output text)
  
  if [ "$STREAM" = "None" ] || [ -z "$STREAM" ]; then
    print_error "No log streams found for $SERVICE"
    return
  fi
  
  print_info "Latest log stream: $STREAM"
  
  aws logs get-log-events \
    --log-group-name $LOG_GROUP \
    --log-stream-name $STREAM \
    --region $AWS_REGION \
    --start-from-head \
    --query 'events[*].[timestamp,message]' \
    --output text | tail -50
}

force_restart() {
  local SERVICE=$1
  print_header "Force Restarting $SERVICE"
  
  print_info "Initiating deployment with force-new-deployment flag..."
  
  aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE \
    --force-new-deployment \
    --region $AWS_REGION
  
  print_success "Force restart initiated. Waiting for tasks to restart..."
  sleep 10
  check_status
}

get_alb_url() {
  print_header "Getting ALB URL"
  
  ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names my-app-alb \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].DNSName' \
    --output text)
  
  if [ "$ALB_DNS" = "None" ] || [ -z "$ALB_DNS" ]; then
    print_error "Could not find ALB"
    return
  fi
  
  print_success "ALB DNS Name: $ALB_DNS"
  echo ""
  print_info "Frontend: http://$ALB_DNS"
  print_info "Backend API: http://$ALB_DNS/api/users"
  print_info "Health Check: http://$ALB_DNS/api/health"
}

test_connectivity() {
  print_header "Testing Connectivity"
  
  # Get ALB URL
  ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names my-app-alb \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].DNSName' \
    --output text)
  
  if [ "$ALB_DNS" = "None" ] || [ -z "$ALB_DNS" ]; then
    print_error "Could not find ALB"
    return
  fi
  
  BASE_URL="http://$ALB_DNS"
  
  print_info "Testing $BASE_URL/api/health..."
  
  HEALTH=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/api/health)
  if [ "$HEALTH" = "200" ]; then
    print_success "Health check: $HEALTH"
  else
    print_error "Health check: $HEALTH"
  fi
  
  print_info "Testing $BASE_URL/api/users..."
  
  USERS=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/api/users)
  if [ "$USERS" = "200" ]; then
    print_success "Users endpoint: $USERS"
  else
    print_error "Users endpoint: $USERS"
  fi
}

get_task_definition() {
  local TASK_DEF=$1
  print_header "Getting Task Definition: $TASK_DEF"
  
  aws ecs describe-task-definition \
    --task-definition $TASK_DEF \
    --region $AWS_REGION \
    --query 'taskDefinition.containerDefinitions[0].environment' \
    --output table
}

# Main menu
show_menu() {
  echo ""
  echo -e "${BLUE}ECS Deployment Helper${NC}"
  echo "1) Check service status"
  echo "2) Check running tasks"
  echo "3) View backend logs"
  echo "4) View frontend logs"
  echo "5) Force restart backend"
  echo "6) Force restart frontend"
  echo "7) Get ALB URL"
  echo "8) Test connectivity"
  echo "9) Get backend task definition"
  echo "10) Get frontend task definition"
  echo "0) Exit"
  echo ""
  read -p "Select option: " choice
}

# Main script
if [ $# -eq 0 ]; then
  # Interactive menu
  while true; do
    show_menu
    
    case $choice in
      1) check_status ;;
      2) check_tasks ;;
      3) view_logs $BACKEND_TASK_DEF ;;
      4) view_logs $FRONTEND_TASK_DEF ;;
      5) force_restart $BACKEND_SERVICE ;;
      6) force_restart $FRONTEND_SERVICE ;;
      7) get_alb_url ;;
      8) test_connectivity ;;
      9) get_task_definition $BACKEND_TASK_DEF ;;
      10) get_task_definition $FRONTEND_TASK_DEF ;;
      0) print_info "Exiting"; exit 0 ;;
      *) print_error "Invalid option" ;;
    esac
  done
else
  # Command line argument
  case $1 in
    status) check_status ;;
    tasks) check_tasks ;;
    logs-backend) view_logs $BACKEND_TASK_DEF ;;
    logs-frontend) view_logs $FRONTEND_TASK_DEF ;;
    restart-backend) force_restart $BACKEND_SERVICE ;;
    restart-frontend) force_restart $FRONTEND_SERVICE ;;
    url) get_alb_url ;;
    test) test_connectivity ;;
    taskdef-backend) get_task_definition $BACKEND_TASK_DEF ;;
    taskdef-frontend) get_task_definition $FRONTEND_TASK_DEF ;;
    *)
      echo "Usage: $0 [command]"
      echo ""
      echo "Commands:"
      echo "  status              - Check service status"
      echo "  tasks               - List running tasks"
      echo "  logs-backend        - View backend logs"
      echo "  logs-frontend       - View frontend logs"
      echo "  restart-backend     - Force restart backend service"
      echo "  restart-frontend    - Force restart frontend service"
      echo "  url                 - Get ALB URL"
      echo "  test                - Test connectivity"
      echo "  taskdef-backend     - Get backend task definition"
      echo "  taskdef-frontend    - Get frontend task definition"
      echo ""
      echo "  (no arguments)       - Interactive menu"
      exit 1
      ;;
  esac
fi
