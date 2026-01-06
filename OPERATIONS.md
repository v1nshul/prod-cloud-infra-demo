# Operations Guide

This guide covers day-to-day operations, CI/CD workflows, rollback procedures, and troubleshooting common issues.

## CI/CD Workflow Overview

### Continuous Integration (CI)

**Trigger**: Pull requests to `main` branch

**Workflow**: `.github/workflows/ci.yml`

**Steps**:
1. Checkout code
2. Set up Python environment
3. Install dependencies
4. Run linter (ruff)
5. Run unit tests with coverage
6. Build Docker image (validation)

**Purpose**: Ensure code quality before merging

### Continuous Deployment (CD)

**Trigger**: 
- Push to `main` branch → Auto-deploy to **staging**
- Manual workflow dispatch → Deploy to **production**

**Workflow**: `.github/workflows/cd.yml`

**Steps**:
1. Build Docker image
2. Push to GHCR with tags:
   - `latest` (main branch)
   - `main-<sha>` (commit SHA)
   - Branch name
3. Deploy to Kubernetes:
   - Update image tag in Kustomize
   - Apply manifests
   - Wait for rollout
   - Get ingress URL
4. Rollback on failure (automatic)

## Deployment Process

### Staging Deployment (Automatic)

When code is pushed to `main`:

1. **Build phase**: Docker image built and pushed to GHCR
2. **Deploy phase**: 
   - Updates `k8s/staging` with new image tag
   - Applies Kubernetes manifests
   - Waits for rollout completion
3. **Verification**: Health checks ensure pods are ready

**Access staging**:
```bash
# Get EC2 instance IP (from Terraform output or AWS console)
INSTANCE_IP=$(terraform output -raw k3s_public_ip)
# Or manually: aws ec2 describe-instances --filters "Name=tag:Name,Values=prod-cloud-infra-demo-k3s" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text

curl http://$INSTANCE_IP/health
```

### Production Deployment (Manual)

**Safety**: Production requires manual approval

1. Go to **GitHub Actions > CD - Build and Deploy**
2. Click **Run workflow**
3. Select:
   - Branch: `main`
   - Environment: `production`
4. Click **Run workflow**
5. Monitor deployment in Actions tab

**Access production**:
```bash
# Get EC2 instance IP
INSTANCE_IP=$(terraform output -raw k3s_public_ip)

curl http://$INSTANCE_IP/health
```

## Rollback Procedures

### Automatic Rollback

If deployment fails, the workflow automatically:
1. Detects failure
2. Runs `kubectl rollout undo`
3. Restores previous working version

### Manual Rollback

#### Option 1: GitHub Actions Workflow

1. Go to **Actions > Manual Rollback**
2. Click **Run workflow**
3. Select:
   - Environment: `staging` or `production`
   - Revision: Leave empty for previous, or specify revision number
4. Click **Run workflow**

#### Option 2: kubectl Command

**Rollback to previous revision**:
```bash
# Staging
kubectl rollout undo deployment/app -n prod-cloud-infra-demo-staging

# Production
kubectl rollout undo deployment/app -n prod-cloud-infra-demo
```

**Rollback to specific revision**:
```bash
# List revisions
kubectl rollout history deployment/app -n prod-cloud-infra-demo

# Rollback to specific revision
kubectl rollout undo deployment/app -n prod-cloud-infra-demo --to-revision=2
```

**Verify rollback**:
```bash
kubectl rollout status deployment/app -n prod-cloud-infra-demo
kubectl get pods -n prod-cloud-infra-demo
```

## Monitoring and Logs

### View Application Logs

**All pods in namespace**:
```bash
# Staging
kubectl logs -n prod-cloud-infra-demo-staging -l app=prod-cloud-infra-demo --tail=100

# Production
kubectl logs -n prod-cloud-infra-demo -l app=prod-cloud-infra-demo --tail=100
```

**Specific pod**:
```bash
kubectl logs -n prod-cloud-infra-demo <pod-name> -f
```

**Previous container (if pod restarted)**:
```bash
kubectl logs -n prod-cloud-infra-demo <pod-name> --previous
```

### Check Pod Status

```bash
# All pods
kubectl get pods -n prod-cloud-infra-demo

# Detailed pod information
kubectl describe pod -n prod-cloud-infra-demo <pod-name>

# Pod events
kubectl get events -n prod-cloud-infra-demo --sort-by='.lastTimestamp'
```

### Check Service Health

```bash
# Test health endpoint
curl http://<alb-url>/health

# Test API endpoint
curl http://<alb-url>/api/v1/example

# Check service endpoints
kubectl get endpoints -n prod-cloud-infra-demo
```

### Resource Usage

```bash
# Pod resource usage
kubectl top pods -n prod-cloud-infra-demo

# Node resource usage
kubectl top nodes
```

## Common Issues and Solutions

### Issue: Pods Not Starting

**Symptoms**:
- Pods in `Pending` or `CrashLoopBackOff` state
- `kubectl get pods` shows errors

**Diagnosis**:
```bash
# Check pod status
kubectl describe pod -n prod-cloud-infra-demo <pod-name>

# Check logs
kubectl logs -n prod-cloud-infra-demo <pod-name>

# Check events
kubectl get events -n prod-cloud-infra-demo
```

**Common causes**:
1. **Image pull errors**: Image doesn't exist or wrong credentials
   - Solution: Verify image in GHCR, check image pull secrets
2. **Resource constraints**: Not enough CPU/memory
   - Solution: Check node resources, adjust resource requests/limits
3. **Health check failures**: Application not responding
   - Solution: Check application logs, verify health endpoint

### Issue: Deployment Stuck

**Symptoms**:
- Deployment shows `0/2 ready` for extended time
- Rollout never completes

**Diagnosis**:
```bash
# Check rollout status
kubectl rollout status deployment/app -n prod-cloud-infra-demo

# Check replica set
kubectl get rs -n prod-cloud-infra-demo

# Check pod status
kubectl get pods -n prod-cloud-infra-demo
```

**Solution**:
1. Check pod logs for errors
2. Verify health checks are passing
3. Check resource limits
4. If needed, rollback: `kubectl rollout undo deployment/app -n prod-cloud-infra-demo`

### Issue: Ingress Not Working

**Symptoms**:
- Can't access application via public IP
- NGINX ingress not responding
- 404 or connection refused errors

**Diagnosis**:
```bash
# Check ingress
kubectl describe ingress -n prod-cloud-infra-demo app-ingress

# Check NGINX ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Check service endpoints
kubectl get endpoints -n prod-cloud-infra-demo
```

**Common causes**:
1. **NGINX Ingress Controller not running**: Check pod status
   - Solution: `kubectl get pods -n ingress-nginx` and check logs
2. **Security group**: Ports 80/443 not open
   - Solution: Verify security group allows inbound traffic on 80/443
3. **Service not ready**: Backend service not running
   - Solution: Check application pods are running and healthy
4. **Ingress configuration**: Wrong ingress class or annotations
   - Solution: Verify `ingressClassName: nginx` in ingress manifest

### Issue: High AWS Costs

**Symptoms**:
- Unexpected AWS bill
- Costs higher than expected

**Check**:
1. **Instance count**: Verify only one EC2 instance running
   ```bash
   aws ec2 describe-instances --filters "Name=tag:Name,Values=prod-cloud-infra-demo-k3s" --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]' --output table
   ```
2. **Instance type**: Verify using t3.micro or t3.small
   - Solution: Check instance type in AWS console or Terraform
3. **EBS volumes**: Check for orphaned volumes
   ```bash
   aws ec2 describe-volumes --filters "Name=tag:Name,Values=prod-cloud-infra-demo*" --query 'Volumes[*].[VolumeId,Size,State]' --output table
   ```
4. **Elastic IPs**: Check for unused Elastic IPs
   ```bash
   aws ec2 describe-addresses --query 'Addresses[*].[PublicIp,AssociationId]' --output table
   ```
5. **Data transfer**: Monitor data transfer costs

**Solutions**:
- Use t3.micro (free tier eligible) if possible
- Stop instance during off-hours (k3s will restart cleanly)
- Review and delete unused resources
- Check for resource leaks
- Consider reserved instances for long-term use

## Scaling

### Scale Deployment

**Increase replicas**:
```bash
kubectl scale deployment/app -n prod-cloud-infra-demo --replicas=3
```

**Or edit deployment**:
```bash
kubectl edit deployment/app -n prod-cloud-infra-demo
# Change replicas: 2
```

**Note**: With a single-node k3s cluster, you're limited by the instance resources. Monitor CPU and memory usage.

### Scale Infrastructure (Upgrade Instance)

**Via Terraform**:
1. Edit `terraform/terraform.tfvars`
2. Update `instance_type` (e.g., from t3.micro to t3.small)
3. Run `terraform apply`
4. Instance will be replaced (k3s will reinstall automatically)

**Via AWS Console**:
1. Stop the instance
2. Change instance type
3. Start the instance
4. k3s will restart automatically

## Maintenance Tasks

### Update Application

1. Make code changes
2. Create PR (triggers CI)
3. Merge to main (auto-deploys to staging)
4. Test in staging
5. Manually deploy to production when ready

### Update Infrastructure

1. Edit Terraform files
2. Review changes: `terraform plan`
3. Apply: `terraform apply`
4. Verify: Check cluster and nodes

### Update Kubernetes Manifests

1. Edit manifests in `k8s/`
2. Commit and push
3. CI/CD will deploy automatically (staging)
4. Or apply manually: `kubectl apply -k k8s/staging`

### Clean Up Old Images

GHCR stores all image versions. Periodically clean up:
1. Go to GitHub repository > Packages
2. Select the container package
3. Delete old versions (keep last 5-10)

## Best Practices

1. **Always test in staging first**
2. **Monitor deployments**: Watch GitHub Actions and kubectl
3. **Keep backups**: Export important configurations
4. **Review costs**: Check AWS billing dashboard weekly
5. **Update dependencies**: Keep Python packages and K8s versions current
6. **Document changes**: Update docs when making significant changes
7. **Use rollback**: Don't hesitate to rollback if issues occur

## Emergency Procedures

### Complete Service Outage

1. **Check pod status**: `kubectl get pods -A`
2. **Check node status**: `kubectl get nodes`
3. **Check cluster**: `aws eks describe-cluster --name prod-cloud-infra-demo-cluster`
4. **Rollback if needed**: `kubectl rollout undo deployment/app -n prod-cloud-infra-demo`
5. **Scale up if needed**: Increase replicas or nodes

### Security Incident

1. **Rotate secrets**: Update GitHub secrets and Kubernetes secrets
2. **Review access logs**: Check CloudTrail and GitHub audit logs
3. **Isolate if needed**: Scale down or delete compromised resources
4. **Update credentials**: Rotate AWS keys, GitHub tokens

---

**Remember**: When in doubt, rollback. It's better to have a working previous version than a broken new one.

