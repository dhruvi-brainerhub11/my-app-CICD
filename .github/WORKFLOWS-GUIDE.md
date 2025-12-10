# GitHub Actions Workflows Configuration Guide

## Overview

This project includes three GitHub Actions workflows for CI/CD:

1. **build-push-ecr.yml** - Build and push Docker images to ECR
2. **deploy-ecs.yml** - Deploy to ECS Fargate
3. **code-quality.yml** - Code quality checks and tests
                                                                                                        q
## Prerequisites

### AWS Setup

1. Create an AWS account and set up IAM permissions
2. Create ECR repositories:
   ```bash
   aws ecr create-repository --repository-name user-app-backend
   aws ecr create-repository --repository-name user-app-frontend
   ```

3. Create OIDC provider for GitHub Actions:
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
   ```

4. Create IAM role with OIDC trust relationship

### GitHub Setup

1. Fork/create the repository on GitHub
2. Add the following secrets in repository settings:
   - `AWS_ROLE_TO_ASSUME`: ARN of IAM role
   - `AWS_REGION`: AWS region (e.g., us-east-1)

## Workflow Details

### 1. Build and Push to ECR (build-push-ecr.yml)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`

**Jobs:**
- Build backend Docker image
- Build frontend Docker image
- Push both images to ECR
- Optional: Trigger ECS deployment

**Environment Variables (update in workflow):**
```yaml
ECR_REGISTRY_BACKEND: user-app-backend
ECR_REGISTRY_FRONTEND: user-app-frontend
AWS_REGION: us-east-1
```

### 2. Deploy to ECS Fargate (deploy-ecs.yml)

**Triggers:**
- Push to `main` branch only
- Manual trigger (workflow_dispatch)

**Jobs:**
- Download backend task definition
- Update with latest image
- Deploy backend to ECS
- Download frontend task definition
- Update with latest image
- Deploy frontend to ECS

**Prerequisites:**
- ECS cluster created
- ECS services created
- Task definitions registered

**Environment Variables (update in workflow):**
```yaml
ECS_CLUSTER: user-app-cluster
ECS_SERVICE_BACKEND: user-app-backend-service
ECS_SERVICE_FRONTEND: user-app-frontend-service
ECS_TASK_DEFINITION_BACKEND: user-app-backend
ECS_TASK_DEFINITION_FRONTEND: user-app-frontend
AWS_REGION: us-east-1
```

### 3. Code Quality (code-quality.yml)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`

**Jobs:**
- Lint backend code
- Lint frontend code
- Build Docker images (validation)

## Setting Up Secrets

### Using GitHub CLI

```bash
gh secret set AWS_ROLE_TO_ASSUME -b "arn:aws:iam::123456789:role/GitHubActionsRole" -R username/user-app
gh secret set AWS_REGION -b "us-east-1" -R username/user-app
```

### Using GitHub Web UI

1. Go to repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each secret:
   - Name: `AWS_ROLE_TO_ASSUME`, Value: IAM role ARN
   - Name: `AWS_REGION`, Value: AWS region

## Customization

### Update image registry

In `build-push-ecr.yml`, change:
```yaml
ECR_REGISTRY_BACKEND: your-registry/your-backend-name
ECR_REGISTRY_FRONTEND: your-registry/your-frontend-name
```

### Update ECS cluster details

In `deploy-ecs.yml`, update:
```yaml
ECS_CLUSTER: your-cluster-name
ECS_SERVICE_BACKEND: your-backend-service
ECS_SERVICE_FRONTEND: your-frontend-service
```

### Add additional branches

In workflow `on.push.branches`, add:
```yaml
branches:
  - main
  - develop
  - staging
```

### Conditional deployment

Deploy only on specific conditions:
```yaml
if: github.ref == 'refs/heads/main' && github.event_name == 'push'
```

## Troubleshooting

### Workflow fails with "Invalid request"

Check that AWS credentials are configured correctly and secrets are set.

### ECR images not found

Verify:
- ECR repositories exist
- Repository names match workflow configuration
- AWS credentials have ECR permissions

### ECS deployment fails

Check:
- ECS cluster exists
- ECS services exist
- Task definitions exist
- IAM role has ECS permissions

### Build timeout

Increase timeout in workflow (default 360 minutes for jobs)

## Monitoring

1. Go to Actions tab in GitHub
2. Click on workflow run
3. View logs for each job
4. Check AWS CloudWatch for application logs

## Best Practices

1. **Secrets Management**
   - Never hardcode secrets
   - Use GitHub Secrets for sensitive data
   - Rotate secrets regularly

2. **Workflow Optimization**
   - Use caching for dependencies
   - Parallelize independent jobs
   - Set appropriate timeouts

3. **Deployment Safety**
   - Always test in develop branch first
   - Use auto-scaling for production
   - Monitor deployment in ECS console

4. **Security**
   - Use OIDC for AWS authentication (no long-lived credentials)
   - Restrict IAM permissions to minimum required
   - Enable branch protection rules

## Common Issues

### "Role not found"

Make sure the IAM role ARN is correct:
```bash
aws iam get-role --role-name GitHubActionsRole
```

### "Repository not found"

Verify ECR repositories exist:
```bash
aws ecr describe-repositories
```

### Authentication errors

Check AWS credentials and permissions. Grant these policies:
- ECR push/pull permissions
- ECS deployment permissions
- CloudWatch logs access

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [OIDC with GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
