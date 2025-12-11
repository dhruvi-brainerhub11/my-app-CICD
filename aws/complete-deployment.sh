#!/bin/bash

###############################################################################
# Complete AWS ECS Deployment Automation Script
# This script automates the entire deployment process:
# 1. Builds Docker images
# 2. Pushes to ECR
# 3. Registers task definitions
# 4. Creates/Updates ECS services
#
# Prerequisites:
# - AWS CLI configured
# - Docker installed
# - GitHub code pushed
# - AWS infrastructure set up (VPC, ALB, RDS, etc.)
#
# Usage: ./complete-deployment.sh
###############################################################################

set -e

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PROJECT_NAME="user-app"
GIT_REPO="https://github.com/dhruvi-brainerhub11/my-app-CICD.git"
GIT_BRANCH="main"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Please install Docker."
        exit 1
    fi
    log_success "Docker found"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install AWS CLI."
        exit 1
    fi
    log_success "AWS CLI found"
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_warning "jq not found. Installing..."
        apt-get update && apt-get install -y jq
    fi
    log_success "jq found"
    
    # Check git
    if ! command -v git &> /dev/null; then
        log_error "Git not found. Please install Git."
        exit 1
    fi
    log_success "Git found"
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 1: CLONE/UPDATE REPOSITORY
# ═══════════════════════════════════════════════════════════════════════════

setup_repository() {
    log_info "Setting up repository..."
    
    if [ ! -d "user-app" ]; then
        log_info "Cloning repository..."
        git clone -b "$GIT_BRANCH" "$GIT_REPO" user-app
    else
        log_info "Repository exists, pulling latest changes..."
        cd user-app
        git pull origin "$GIT_BRANCH"
        cd ..
    fi
    
    log_success "Repository ready"
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 2: BUILD AND PUSH DOCKER IMAGES
# ═══════════════════════════════════════════════════════════════════════════

build_and_push_images() {
    log_info "Building and pushing Docker images..."
    
    cd user-app
    
    # Get Git commit SHA for versioning
    GIT_SHA=$(git rev-parse --short HEAD)
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    IMAGE_TAG="$GIT_SHA-$TIMESTAMP"
    
    log_info "Image tag: $IMAGE_TAG"
    
    # ECR Registry
    ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    BACKEND_ECR_REPO="${ECR_REGISTRY}/${PROJECT_NAME}-backend"
    FRONTEND_ECR_REPO="${ECR_REGISTRY}/${PROJECT_NAME}-frontend"
    
    # Login to ECR
    log_info "Logging in to ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
    log_success "Logged in to ECR"
    
    # Build Backend Image
    log_info "Building backend Docker image..."
    docker build -t "${BACKEND_ECR_REPO}:${IMAGE_TAG}" -t "${BACKEND_ECR_REPO}:latest" ./backend
    log_success "Backend image built"
    
    # Build Frontend Image
    log_info "Building frontend Docker image..."
    docker build -t "${FRONTEND_ECR_REPO}:${IMAGE_TAG}" -t "${FRONTEND_ECR_REPO}:latest" ./frontend
    log_success "Frontend image built"
    
    # Push Backend Image
    log_info "Pushing backend image to ECR..."
    docker push "${BACKEND_ECR_REPO}:${IMAGE_TAG}"
    docker push "${BACKEND_ECR_REPO}:latest"
    log_success "Backend image pushed"
    
    # Push Frontend Image
    log_info "Pushing frontend image to ECR..."
    docker push "${FRONTEND_ECR_REPO}:${IMAGE_TAG}"
    docker push "${FRONTEND_ECR_REPO}:latest"
    log_success "Frontend image pushed"
    
    cd ..
    
    # Return values for later use
    export BACKEND_IMAGE="${BACKEND_ECR_REPO}:${IMAGE_TAG}"
    export FRONTEND_IMAGE="${FRONTEND_ECR_REPO}:${IMAGE_TAG}"
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 3: UPDATE TASK DEFINITIONS AND DEPLOY
# ═══════════════════════════════════════════════════════════════════════════

deploy_to_ecs() {
    log_info "Deploying to ECS..."
    
    cd user-app/aws
    
    # Make deploy script executable
    chmod +x deploy-ecs-services.sh
    
    # Run deployment with image URIs
    ./deploy-ecs-services.sh "$BACKEND_IMAGE" "$FRONTEND_IMAGE"
    
    cd ../..
}

# ═══════════════════════════════════════════════════════════════════════════
# VERIFICATION
# ═══════════════════════════════════════════════════════════════════════════

verify_deployment() {
    log_info "Verifying deployment..."
    
    ECS_CLUSTER="${PROJECT_NAME}-cluster"
    BACKEND_SERVICE="${PROJECT_NAME}-backend-service"
    FRONTEND_SERVICE="${PROJECT_NAME}-frontend-service"
    
    # Check backend service
    BACKEND_STATUS=$(aws ecs describe-services \
        --cluster "$ECS_CLUSTER" \
        --services "$BACKEND_SERVICE" \
        --region "$AWS_REGION" \
        --query 'services[0].status' \
        --output text 2>/dev/null || echo "INACTIVE")
    
    # Check frontend service
    FRONTEND_STATUS=$(aws ecs describe-services \
        --cluster "$ECS_CLUSTER" \
        --services "$FRONTEND_SERVICE" \
        --region "$AWS_REGION" \
        --query 'services[0].status' \
        --output text 2>/dev/null || echo "INACTIVE")
    
    echo ""
    echo "Service Status:"
    echo "  Backend Service: $BACKEND_STATUS"
    echo "  Frontend Service: $FRONTEND_STATUS"
    echo ""
    
    # Get ALB DNS
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --query "LoadBalancers[?LoadBalancerName=='${PROJECT_NAME}-alb'].DNSName" \
        --region "$AWS_REGION" \
        --output text)
    
    if [ -n "$ALB_DNS" ]; then
        log_success "Application accessible at: http://$ALB_DNS"
        
        # Wait for targets to be healthy
        log_info "Waiting for ALB targets to become healthy..."
        sleep 30
        
        # Test API
        log_info "Testing backend API..."
        if curl -s "http://$ALB_DNS/api/health" > /dev/null 2>&1; then
            log_success "Backend API is responding"
        else
            log_warning "Backend API not yet responding (may take a minute)"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  Complete AWS ECS Deployment Automation                        ║"
    echo "║  Project: $PROJECT_NAME"
    echo "║  Region: $AWS_REGION"
    echo "║  Account ID: $AWS_ACCOUNT_ID"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Setup repository
    setup_repository
    echo ""
    
    # Build and push images
    build_and_push_images
    echo ""
    
    # Deploy to ECS
    deploy_to_ecs
    echo ""
    
    # Verify deployment
    verify_deployment
    echo ""
    
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ✅ Complete Deployment Successful!                            ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

# Run main function
main "$@"
