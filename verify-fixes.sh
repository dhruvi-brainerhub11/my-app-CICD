#!/bin/bash

# 🔍 CODE VERIFICATION SCRIPT
# Run this to verify all fixes have been applied correctly

echo "======================================"
echo "🔍 VERIFYING CODE FIXES..."
echo "======================================"
echo ""

ERRORS=0
WARNINGS=0

# Check 1: Frontend .env has correct ALB URL
echo "Check 1: Frontend .env ALB URL..."
if grep -q "http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com" frontend/.env; then
  echo "✅ PASS: Frontend .env has correct ALB URL with protocol"
else
  echo "❌ FAIL: Frontend .env missing correct ALB URL"
  ((ERRORS++))
fi
echo ""

# Check 2: Frontend App.js has correct fallback URL
echo "Check 2: Frontend App.js fallback URL..."
if grep -q "http://localhost:5000" frontend/src/App.js; then
  echo "✅ PASS: App.js has correct fallback URL"
else
  echo "❌ FAIL: App.js fallback URL incorrect"
  ((ERRORS++))
fi
echo ""

# Check 3: Frontend Dockerfile exposes port 80
echo "Check 3: Frontend Dockerfile port..."
if grep -q "EXPOSE 80" frontend/Dockerfile; then
  echo "✅ PASS: Dockerfile exposes port 80"
else
  echo "❌ FAIL: Dockerfile doesn't expose port 80"
  ((ERRORS++))
fi
echo ""

# Check 4: Docker compose has correct port mapping
echo "Check 4: Docker Compose port mapping..."
if grep -A2 "frontend:" docker-compose.yml | grep -q '"80:80"'; then
  echo "✅ PASS: Docker Compose has correct port mapping 80:80"
else
  echo "⚠️  WARNING: Docker Compose port mapping might be incorrect"
  ((WARNINGS++))
fi
echo ""

# Check 5: Backend .env file exists
echo "Check 5: Backend .env file..."
if [ -f "backend/.env" ]; then
  echo "✅ PASS: backend/.env file exists"
else
  echo "❌ FAIL: backend/.env file missing"
  ((ERRORS++))
fi
echo ""

# Check 6: Backend .env has correct values
echo "Check 6: Backend .env content..."
if grep -q "DB_HOST=myappdb.c9oq2ky8kisq.ap-south-1.rds.amazonaws.com" backend/.env; then
  echo "✅ PASS: Backend .env has correct DB_HOST"
else
  echo "❌ FAIL: Backend .env has incorrect DB_HOST"
  ((ERRORS++))
fi
echo ""

# Check 7: Backend .env example has correct CORS
echo "Check 7: Backend .env.example CORS..."
if grep -q "http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com" backend/.env.example; then
  echo "✅ PASS: Backend .env.example has correct CORS_ORIGIN"
else
  echo "❌ FAIL: Backend .env.example has incorrect CORS_ORIGIN"
  ((ERRORS++))
fi
echo ""

# Check 8: Frontend .env.example exists
echo "Check 8: Frontend .env.example..."
if [ -f "frontend/.env.example" ]; then
  echo "✅ PASS: frontend/.env.example file exists"
else
  echo "⚠️  WARNING: frontend/.env.example file not found"
  ((WARNINGS++))
fi
echo ""

# Check 9: Docker files exist
echo "Check 9: Docker files..."
if [ -f "backend/Dockerfile" ] && [ -f "frontend/Dockerfile" ] && [ -f "docker-compose.yml" ]; then
  echo "✅ PASS: All Docker files present"
else
  echo "❌ FAIL: Some Docker files missing"
  ((ERRORS++))
fi
echo ""

# Check 10: GitHub workflow files exist
echo "Check 10: GitHub Workflows..."
if [ -f ".github/workflows/build-push-ecr.yml" ] && [ -f ".github/workflows/deploy-ecs.yml" ]; then
  echo "✅ PASS: Both GitHub workflow files present"
else
  echo "❌ FAIL: GitHub workflow files missing"
  ((ERRORS++))
fi
echo ""

# Summary
echo "======================================"
echo "📊 VERIFICATION SUMMARY"
echo "======================================"
echo "✅ Passed: $((10 - ERRORS - WARNINGS)) / 10"
echo "❌ Errors: $ERRORS"
echo "⚠️  Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ]; then
  echo "✅ ALL CHECKS PASSED! Code is ready for deployment."
  exit 0
else
  echo "❌ Some checks failed. Please fix the issues above."
  exit 1
fi
