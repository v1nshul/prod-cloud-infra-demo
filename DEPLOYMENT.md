# Deployment Guide

This guide walks you through setting up the entire infrastructure and deploying the application from scratch using k3s on a single EC2 instance.

## Prerequisites

Before starting, ensure you have:

1. **AWS Account** with appropriate permissions (EC2, VPC, IAM)
2. **GitHub Account** with a repository
3. **Local tools installed**:
   - Terraform >= 1.5.0
   - AWS CLI configured
   - kubectl
   - SSH client
   - Docker (for local testing)
   - Python 3.11+ (for local development)

## Step 1: Clone and Prepare Repository

```bash
git clone <your-repo-url>
cd prod-cloud-infra-demo
```

## Step 2: Configure Terraform Variables

1. Copy the example variables file:
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

2. Edit `terraform/terraform.tfvars` with your values:
```hcl
aws_region        = "eu-west-2"
project_name      = "prod-cloud-infra-demo"
environment       = "production"
github_username   = "your-github-username"

# EC2 instance configuration (free tier or near-free tier)
instance_type     = "t3.micro"  # Free tier eligible, or t3.small for better performance
disk_size         = 20         # Free tier eligible (20GB)
```

## Step 3: Update Kubernetes Manifests

1. Update the container image in `k8s/base/deployment.yaml`:
```yaml
image: ghcr.io/YOUR_GITHUB_USERNAME/prod-cloud-infra-demo:latest
```
Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username.

## Step 4: Configure GitHub Secrets

In your GitHub repository, go to **Settings > Secrets and variables > Actions** and add:

- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `K3S_KUBECONFIG`: (We'll add this after Step 6)

## Step 5: Deploy Infrastructure with Terraform

1. Navigate to the Terraform directory:
```bash
cd terraform
```

2. Initialize Terraform:
```bash
terraform init
```

3. Review the planned changes:
```bash
terraform plan
```

This will create:
- VPC with public subnet
- Security group for k3s
- EC2 instance with k3s pre-installed
- Elastic IP for stable access
- SSH key pair

4. Apply the infrastructure:
```bash
terraform apply
```

**Expected time**: 3-5 minutes (much faster than EKS!)

5. Save the outputs:
```bash
terraform output -json > ../terraform-outputs.json
```

6. Note the instance IP and SSH key:
```bash
terraform output k3s_public_ip
terraform output ssh_private_key_path
```

## Step 6: Configure kubectl for k3s

1. **SSH to the k3s instance** to get the kubeconfig:
```bash
# Get the SSH key path from Terraform output
SSH_KEY=$(terraform output -raw ssh_private_key_path)
INSTANCE_IP=$(terraform output -raw k3s_public_ip)

# SSH to the instance
ssh -i $SSH_KEY ec2-user@$INSTANCE_IP
```

2. **On the instance, copy the kubeconfig**:
```bash
# On the k3s instance
sudo cat /etc/rancher/k3s/k3s.yaml
```

3. **On your local machine**, create the kubeconfig:
```bash
# Create kubeconfig directory
mkdir -p ~/.kube

# Copy kubeconfig content and save to file
# Replace <INSTANCE_IP> with the actual IP from terraform output
cat > ~/.kube/k3s-config <<EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: <CERT_DATA>
    server: https://<INSTANCE_IP>:6443
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
users:
- name: default
  user:
    token: <TOKEN>
EOF
```

**Or use the automated method**:
```bash
# From your local machine
SSH_KEY=$(terraform output -raw ssh_private_key_path)
INSTANCE_IP=$(terraform output -raw k3s_public_ip)

# Copy kubeconfig from instance
scp -i $SSH_KEY ec2-user@$INSTANCE_IP:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config

# Update server URL to use public IP
sed -i "s/127.0.0.1/$INSTANCE_IP/g" ~/.kube/k3s-config
sed -i "s/localhost/$INSTANCE_IP/g" ~/.kube/k3s-config
```

4. **Set KUBECONFIG and verify**:
```bash
export KUBECONFIG=~/.kube/k3s-config
kubectl get nodes
```

You should see your k3s node listed.

## Step 7: Add kubeconfig to GitHub Secrets

1. **Encode the kubeconfig** (for GitHub secret):
```bash
# Base64 encode (recommended)
cat ~/.kube/k3s-config | base64

# Or just copy the content directly
cat ~/.kube/k3s-config
```

2. **Add to GitHub Secrets**:
   - Go to **Settings > Secrets and variables > Actions**
   - Click **New repository secret**
   - Name: `K3S_KUBECONFIG`
   - Value: Paste the base64-encoded kubeconfig or the raw content
   - Click **Add secret**

## Step 8: Verify k3s Setup

1. Check that k3s is running:
```bash
kubectl get nodes
kubectl get pods -A
```

2. Verify NGINX Ingress Controller is installed:
```bash
kubectl get pods -n ingress-nginx
```

3. Check namespaces:
```bash
kubectl get namespaces | grep prod-cloud-infra-demo
```

## Step 9: Deploy Application Manually (First Time)

Before CI/CD takes over, deploy manually to verify everything works:

1. Build and push the Docker image:
```bash
# Build locally
docker build -t ghcr.io/YOUR_GITHUB_USERNAME/prod-cloud-infra-demo:latest .

# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# Push
docker push ghcr.io/YOUR_GITHUB_USERNAME/prod-cloud-infra-demo:latest
```

2. Deploy to staging:
```bash
export KUBECONFIG=~/.kube/k3s-config
cd k8s/staging
kubectl apply -k .
```

3. Check deployment status:
```bash
kubectl get pods -n prod-cloud-infra-demo-staging
kubectl get svc -n prod-cloud-infra-demo-staging
kubectl get ingress -n prod-cloud-infra-demo-staging
```

4. Get the application URL:
```bash
INSTANCE_IP=$(terraform output -raw k3s_public_ip)
echo "Application URL: http://$INSTANCE_IP"
```

5. Test the application:
```bash
INSTANCE_IP=$(terraform output -raw k3s_public_ip)
curl http://$INSTANCE_IP/health
curl http://$INSTANCE_IP/api/v1/example
```

## Step 10: Set Up CI/CD

1. Push your code to GitHub:
```bash
git add .
git commit -m "Initial setup"
git push origin main
```

2. The CI workflow will run on push:
   - Lint and test the code
   - Build Docker image
   - Push to GHCR
   - Deploy to staging automatically

3. Monitor the workflow in GitHub Actions tab

## Step 11: Deploy to Production

Production deployments are **manual** for safety:

1. Go to **Actions > CD - Build and Deploy**
2. Click **Run workflow**
3. Select **production** environment
4. Click **Run workflow**

## Step 12: Verify Production Deployment

```bash
export KUBECONFIG=~/.kube/k3s-config

# Check pods
kubectl get pods -n prod-cloud-infra-demo

# Check services
kubectl get svc -n prod-cloud-infra-demo

# Get production URL
INSTANCE_IP=$(terraform output -raw k3s_public_ip)
echo "Production URL: http://$INSTANCE_IP"

# Test
curl http://$INSTANCE_IP/health
```

## Troubleshooting

### Terraform Issues

**Error: Insufficient permissions**
- Ensure your AWS credentials have EC2, VPC, and IAM permissions

**Error: Key pair already exists**
- Delete the existing key pair or use a different project name

**Error: Instance not starting**
- Check security group allows SSH (port 22)
- Verify instance type is available in your region

### k3s Issues

**Can't connect to k3s**
- Verify kubeconfig server URL matches instance public IP
- Check security group allows port 6443 (k3s API)
- Ensure k3s service is running: `sudo systemctl status k3s` (on instance)

**NGINX Ingress not working**
- Verify ingress controller is running: `kubectl get pods -n ingress-nginx`
- Check ingress resource: `kubectl describe ingress -n <namespace>`
- Verify security group allows ports 80 and 443

**Pods not starting**
- Check pod logs: `kubectl logs -n <namespace> <pod-name>`
- Check events: `kubectl describe pod -n <namespace> <pod-name>`
- Verify image exists in GHCR

### CI/CD Issues

**GitHub Actions failing**
- Check workflow logs in Actions tab
- Verify GitHub secrets are set correctly (especially K3S_KUBECONFIG)
- Ensure AWS credentials have correct permissions
- Verify kubeconfig format is correct

**Deployment fails**
- Check kubectl can connect: Test locally first
- Verify kubeconfig in GitHub secret is up-to-date
- Check instance is running: `aws ec2 describe-instances`

## Tearing Down

To completely remove all infrastructure:

1. Delete Kubernetes resources (optional):
```bash
export KUBECONFIG=~/.kube/k3s-config
kubectl delete -k k8s/staging
kubectl delete -k k8s/production
```

2. Destroy Terraform infrastructure:
```bash
cd terraform
terraform destroy
```

**Note**: This will delete everything. Make sure you have backups if needed.

## Next Steps

- Review [OPERATIONS.md](OPERATIONS.md) for day-to-day operations
- Set up monitoring and alerting (optional)
- Configure custom domain (optional)
- Review and adjust resource limits based on usage
- Consider upgrading to t3.small if you need more performance

---

**Important**: Always test in staging before deploying to production!

**Cost reminder**: This setup costs ~$10-15/month (or free tier eligible). Monitor your AWS billing dashboard.
