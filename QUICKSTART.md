# Quick Start Guide

Get up and running in 5 minutes (after initial setup).

## Prerequisites Check

```bash
# Verify tools are installed
terraform version  # Should be >= 1.5.0
aws --version
kubectl version --client
docker --version
python --version  # Should be 3.11+
```

## Initial Setup (One-Time)

1. **Configure AWS CLI**:
```bash
aws configure
```

2. **Verify container image** in `k8s/base/deployment.yaml`:
```yaml
image: ghcr.io/v1nshul/prod-cloud-infra-demo:latest
```

3. **Configure Terraform**:
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

4. **Deploy Infrastructure**:
```bash
terraform init
terraform plan
terraform apply
```

5. **Configure kubectl for k3s**:
```bash
# Get SSH key and instance IP from Terraform
SSH_KEY=$(terraform output -raw ssh_private_key_path)
INSTANCE_IP=$(terraform output -raw k3s_public_ip)

# Copy kubeconfig from instance
scp -i $SSH_KEY ec2-user@$INSTANCE_IP:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config

# Update server URL
sed -i "s/127.0.0.1/$INSTANCE_IP/g" ~/.kube/k3s-config

# Set KUBECONFIG and verify
export KUBECONFIG=~/.kube/k3s-config
kubectl get nodes  # Verify connection
```

6. **Set GitHub Secrets** (in repository settings):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `K3S_KUBECONFIG`: Copy content from `~/.kube/k3s-config` (base64 encode or paste directly)

## Daily Workflow

### Making Changes

1. **Create feature branch**:
```bash
git checkout -b feature/my-feature
```

2. **Make changes and test locally**:
```bash
make test
make lint
```

3. **Create PR** → CI runs automatically

4. **Merge to main** → Auto-deploys to staging

5. **Test staging**, then manually deploy to production via GitHub Actions

### Common Commands

```bash
# Run tests
make test

# Lint code
make lint

# Build Docker image
make docker-build

# Deploy to staging
make deploy-staging

# Deploy to production
make deploy-prod

# View logs
kubectl logs -n prod-cloud-infra-demo -l app=prod-cloud-infra-demo -f

# Check status
kubectl get pods -n prod-cloud-infra-demo
kubectl get ingress -n prod-cloud-infra-demo
```

### Rollback

```bash
# Quick rollback
kubectl rollout undo deployment/app -n prod-cloud-infra-demo

# Or use GitHub Actions: Actions > Manual Rollback
```

## Troubleshooting

**Pods not starting?**
```bash
kubectl describe pod -n prod-cloud-infra-demo <pod-name>
kubectl logs -n prod-cloud-infra-demo <pod-name>
```

**Can't access application?**
```bash
# Get EC2 instance IP
INSTANCE_IP=$(terraform output -raw k3s_public_ip)

# Test health endpoint
curl http://$INSTANCE_IP/health
```

**CI/CD failing?**
- Check GitHub Actions logs
- Verify secrets are set
- Check AWS credentials have correct permissions

## Cost Monitoring

```bash
# Check node count
kubectl get nodes

# Check running pods
kubectl get pods -A

# AWS Console: Check billing dashboard
```

## Cleanup

```bash
# Delete application (optional)
export KUBECONFIG=~/.kube/k3s-config
kubectl delete -k k8s/staging
kubectl delete -k k8s/production

# Destroy infrastructure
cd terraform
terraform destroy
```

## Cost Monitoring

```bash
# Check instance status
aws ec2 describe-instances --filters "Name=tag:Name,Values=prod-cloud-infra-demo-k3s" --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]' --output table

# Expected cost: ~$10-15/month (or free tier eligible)
```

---

**Need more details?** See [DEPLOYMENT.md](DEPLOYMENT.md) and [OPERATIONS.md](OPERATIONS.md)

