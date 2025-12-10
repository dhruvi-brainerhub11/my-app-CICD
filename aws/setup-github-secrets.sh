#!/bin/bash

# User App GitHub Setup Script
# Configure GitHub secrets for CI/CD

set -e

if [ -z "$GITHUB_REPO" ]; then
  echo "Please set GITHUB_REPO environment variable (e.g., username/repo)"
  exit 1
fi

if [ -z "$AWS_ROLE_ARN" ]; then
  echo "Please set AWS_ROLE_ARN environment variable"
  exit 1
fi

if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"
fi

echo "=========================================="
echo "GitHub CI/CD Setup"
echo "=========================================="
echo "Repository: $GITHUB_REPO"
echo "AWS Role: $AWS_ROLE_ARN"
echo "AWS Region: $AWS_REGION"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
  echo "❌ GitHub CLI is required. Install it from https://cli.github.com"
  exit 1
fi

# Set GitHub secrets
echo "Setting GitHub Secrets..."

gh secret set AWS_ROLE_TO_ASSUME -b "$AWS_ROLE_ARN" --repo "$GITHUB_REPO"
echo "✅ AWS_ROLE_TO_ASSUME set"

gh secret set AWS_REGION -b "$AWS_REGION" --repo "$GITHUB_REPO"
echo "✅ AWS_REGION set"

echo ""
echo "=========================================="
echo "✅ GitHub Secrets Configured!"
echo "=========================================="
echo ""
echo "Configured Secrets:"
echo "  AWS_ROLE_TO_ASSUME: $AWS_ROLE_ARN"
echo "  AWS_REGION: $AWS_REGION"
echo ""
