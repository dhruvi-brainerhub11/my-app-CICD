# 🚀 ECS Deployment - Next Steps (Quick Action Plan)

## Current Status
✅ Code is on GitHub (my-app-CICD)  
✅ Configuration updated with your AWS details  
✅ Docker images ready to build  
✅ GitHub Actions workflows ready  

**⏳ Now you need to:**

---

## Step 1️⃣: Add GitHub Secrets (5 minutes) - DO THIS FIRST

Your AWS credentials are needed for GitHub Actions to deploy.

### How to Add Secrets:

1. **Go to GitHub**: https://github.com/dhruvi-brainerhub11/my-app-CICD/settings/secrets/actions

2. **Click "New repository secret"** and add these 3 secrets:

```
Secret 1:
Name: AWS_ACCESS_KEY_ID
Value: (your AWS access key from IAM)

Secret 2:
Name: AWS_SECRET_ACCESS_KEY
Value: (your AWS secret key from IAM)

Secret 3:
Name: AWS_REGION
Value: ap-south-1
```

⚠️ **Don't have AWS credentials?**
- Go to AWS Console → IAM → Users → Your user → Security Credentials
- Create new access key (Choose "Command Line Interface")
- Copy and paste here

---

## Step 2️⃣: Create ECR Repositories (2 minutes)

GitHub Actions will push Docker images to ECR. You need to create the repositories first.

### Using AWS CLI (Easiest):

```bash
aws ecr create-repository \
  --repository-name user-app-backend \
  --region ap-south-1

aws ecr create-repository \
  --repository-name user-app-frontend \
  --region ap-south-1
```

### Or Using AWS Console:
- Go to **AWS Console** → **ECR**
- Click **"Create repository"**
- Create `user-app-backend`
- Create `user-app-frontend`

---

## Step 3️⃣: Update ECS Task Definitions (10 minutes)

Add environment variables so your services can connect to RDS and ALB.

### Backend Task Definition:

1. Go to **AWS Console** → **ECS** → **Task Definitions** → **user-app-backend**
2. Click **"Create new revision"**
3. Find **Container definitions** → **user-app-backend**
4. Scroll to **Environment variables** and add these:

```json
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
  "value": "http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com"
}
```

5. Click **"Create"** at bottom

### Frontend Task Definition:

1. Go to **Task Definitions** → **user-app-frontend**
2. Click **"Create new revision"**
3. Find **Container definitions** → **user-app-frontend**
4. Add these environment variables:

```json
{
  "name": "REACT_APP_API_URL",
  "value": "http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com"
},
{
  "name": "REACT_APP_API_TIMEOUT",
  "value": "30000"
}
```

5. Click **"Create"**

---

## Step 4️⃣: Configure Security Groups (10 minutes)

Ensure services can talk to each other.

### What You Need to Allow:

1. **ALB → ECS Tasks** (Port 5000 for backend, 80 for frontend)
   - Go to ECS Task Security Group
   - Add inbound rule: Port 5000 & 80, Source: ALB Security Group

2. **ECS Tasks → RDS** (Port 3306)
   - Go to ECS Task Security Group
   - Add outbound rule: Port 3306, Destination: RDS Security Group
   - Go to RDS Security Group
   - Add inbound rule: Port 3306, Source: ECS Task Security Group

3. **Internet → ALB** (Port 80)
   - Go to ALB Security Group
   - Add inbound rule: Port 80, Source: 0.0.0.0/0

---

## Step 5️⃣: Trigger Deployment (Automatic!)

Once GitHub Secrets are added, just push code:

```bash
cd /home/admin01/Dhruvi/user-app
git push origin main
```

**What happens automatically:**
1. GitHub Actions workflow starts
2. Builds Docker images for backend & frontend
3. Pushes images to ECR
4. Updates ECS Task Definitions
5. Deploys services to ECS Fargate

---

## Step 6️⃣: Verify Deployment

### Check GitHub Actions:
1. Go to: https://github.com/dhruvi-brainerhub11/my-app-CICD/actions
2. Click the latest workflow run
3. Watch both jobs complete:
   - `build-and-push` (pushes to ECR)
   - `deploy` (deploys to ECS)

### Check ECS Services:
```bash
aws ecs describe-services \
  --cluster user-app-cluster \
  --services user-app-backend-service user-app-frontend-service \
  --region ap-south-1 \
  --query 'services[*].[serviceName,status,runningCount]' \
  --output table
```

Expected output:
```
| serviceName                | status | runningCount |
|----------------------------|--------|--------------|
| user-app-backend-service   | ACTIVE | 1            |
| user-app-frontend-service  | ACTIVE | 1            |
```

### Test Application:
```bash
# Test health check
curl http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com/api/health

# Get users
curl http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com/api/users

# Open in browser
# http://user-app-alb-508171731.ap-south-1.elb.amazonaws.com
```

---

## ⏱️ Time Estimate

| Step | Time | Difficulty |
|------|------|-----------|
| 1. GitHub Secrets | 5 min | Easy ✅ |
| 2. ECR Repositories | 2 min | Easy ✅ |
| 3. Task Definitions | 10 min | Medium 🟡 |
| 4. Security Groups | 10 min | Medium 🟡 |
| 5. Push Code | 1 min | Easy ✅ |
| 6. Verify & Test | 5 min | Easy ✅ |
| **TOTAL** | **33 min** | |

---

## 🎯 Order to Follow

1. ✅ **Step 1 FIRST** (GitHub Secrets) - Required for everything
2. ✅ **Step 2 NEXT** (ECR) - Needed before GitHub Actions runs
3. ✅ **Step 3** (Task Definitions) - Needed for ECS deployment
4. ✅ **Step 4** (Security) - Needed for services to communicate
5. ✅ **Step 5** (Push Code) - Triggers automatic deployment
6. ✅ **Step 6** (Verify) - Confirm everything is working

---

## 🆘 Need Help?

- **Detailed steps**: See `DEPLOYMENT-READY.md` in GitHub repo
- **Troubleshooting**: See `ECS-DEPLOYMENT-GUIDE.md`
- **Architecture**: See `SETUP-SUMMARY.md`

---

## ✨ Summary

Once you complete these 6 steps (33 minutes):

✅ Your app will be running on AWS ECS Fargate  
✅ Frontend accessible at ALB DNS  
✅ Backend API serving requests  
✅ Automatic deployments whenever you push to GitHub  
✅ Complete CI/CD pipeline working  

**Let's do this! 🚀**

---

## Quick Checklist

- [ ] Add GitHub Secrets (AWS credentials)
- [ ] Create ECR repositories (user-app-backend, user-app-frontend)
- [ ] Update Backend Task Definition (add environment variables)
- [ ] Update Frontend Task Definition (add environment variables)
- [ ] Configure Security Groups (allow traffic)
- [ ] Push code to GitHub (`git push origin main`)
- [ ] Monitor GitHub Actions workflow
- [ ] Verify ECS services are running
- [ ] Test application in browser

**Start with Step 1! ⬆️**
