# 🔧 FIX: "Service is INACTIVE" Error

## ❌ Problem
GitHub Actions fails with: **Error: Service is INACTIVE**

This means the ECS services don't exist yet.

---

## ✅ Solution (2 Steps)

### Step 1: Create AWS Infrastructure (15 minutes)

```bash
cd /home/admin01/Dhruvi/user-app
bash aws/setup-complete-infrastructure.sh
```

**This creates:**
- VPC with subnets
- ALB with target groups
- RDS database
- ECS cluster
- Security groups
- CloudWatch logs
- IAM roles
- ECR repositories

**Wait for it to complete.** You'll see:
```
✓ Infrastructure setup complete!
✓ Configuration saved to aws-infrastructure-config.json
```

---

### Step 2: Create ECS Services (5 minutes)

```bash
bash aws/fix-create-services-now.sh
```

**This creates:**
- Backend task definition
- Frontend task definition
- Backend ECS service
- Frontend ECS service
- Links services to ALB

**You'll see:**
```
✅ Backend task definition registered
✅ Frontend task definition registered
✅ Backend service created
✅ Frontend service created
```

---

## 🚀 Then GitHub Actions Will Work!

Now push your code:

```bash
git push origin main
```

GitHub Actions will:
1. Build Docker images ✅
2. Push to ECR ✅
3. Deploy to ECS services ✅
4. Wait for stability ✅
5. Show success ✅

---

## 🔍 Verify It Works

```bash
# Check services are ACTIVE
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1 \
  --query 'services[*].[serviceName,status]' \
  --output table
```

**Expected output:**
```
| serviceName                | status |
|---------------------------|--------|
| user-app-backend-service  | ACTIVE |
| user-app-frontend-service | ACTIVE |
```

---

## ⏱️ Complete Timeline

```
Time 0:    Run: bash aws/setup-complete-infrastructure.sh
Time 15:   Infrastructure created ✅
Time 15:   Run: bash aws/fix-create-services-now.sh
Time 20:   Services created ✅
Time 20:   Run: git push origin main
Time 25:   GitHub Actions triggered
Time 35:   Deployment complete ✅
Time 40:   Application running! 🎉
```

---

## 📋 Full Procedure

```bash
# Step 1: Go to project directory
cd /home/admin01/Dhruvi/user-app

# Step 2: Create infrastructure
bash aws/setup-complete-infrastructure.sh
# Wait ~15 minutes...

# Step 3: Create services
bash aws/fix-create-services-now.sh
# Wait ~5 minutes...

# Step 4: Verify services are ACTIVE
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1 \
  --query 'services[*].status' \
  --output text
# Should show: ACTIVE ACTIVE

# Step 5: Push code to trigger GitHub Actions
git push origin main

# Step 6: Monitor deployment
# Go to GitHub → Actions → Deployments
# Or check logs:
aws logs tail /ecs/user-app-backend --follow --region ap-south-1
```

---

## ✨ What Gets Fixed

| Issue | Cause | Fix |
|-------|-------|-----|
| Service is INACTIVE | Services don't exist | Create them with fix script |
| Task definition error | Task definitions don't exist | Register them with fix script |
| ALB error | Target groups don't exist | Create ALB with infrastructure script |
| Cannot deploy | Infrastructure missing | Run setup-complete-infrastructure.sh |

---

## 🆘 If Still Getting Errors

**Check 1: Cluster exists?**
```bash
aws ecs describe-clusters \
  --clusters user-app-cluster \
  --region ap-south-1 \
  --query 'clusters[0].clusterName'
# Should show: user-app-cluster
```

**Check 2: Services exist?**
```bash
aws ecs list-services \
  --cluster user-app-cluster \
  --region ap-south-1
# Should show service ARNs
```

**Check 3: ALB exists?**
```bash
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?LoadBalancerName=='user-app-alb'].DNSName" \
  --region ap-south-1 --output text
# Should show ALB DNS name
```

**If any return nothing:** Run `bash aws/setup-complete-infrastructure.sh`

---

## 📚 Related Guides

- **Full Setup**: See `QUICK-START-ECS.md`
- **Troubleshooting**: See `TESTING-GUIDE.md`
- **AWS Commands**: See `aws/AWS-CLI-COMMANDS.md`

---

**Summary:**
1. Run infrastructure setup script → Waits 15 min
2. Run fix-create-services script → Waits 5 min
3. Push code → GitHub Actions auto-deploys
4. Done! 🎉

