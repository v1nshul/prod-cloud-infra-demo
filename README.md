# Production Cloud Infrastructure Demo

A production-ready, cost-minimized reference DevOps project designed for UK startups and SMEs. This project demonstrates CI/CD pipelines, containerized application deployment to AWS, Kubernetes orchestration, and GitOps-style deployments—all optimized for **AWS free tier or near-free tier** while maintaining professional standards.

## 🎯 Project Overview

This project serves as a **reference implementation** for solo DevOps consultants offering CI/CD and cloud infrastructure services. It's designed to:

- **Prove capability**: Demonstrate ability to set up CI/CD, deploy containerized apps, and operate Kubernetes
- **Minimize costs**: Run on AWS free tier or near-free tier (single EC2 instance with k3s)
- **Be practical**: Easy to destroy and recreate, fully documented, suitable as a portfolio demo
- **Solve real problems**: Address common startup infrastructure needs without enterprise complexity

## 🏗️ Architecture

### High-Level Design

```
┌─────────────────┐
│   GitHub Repo   │
│  (Source Code)  │
└────────┬────────┘
         │
         │ Push/PR
         ▼
┌─────────────────┐
│ GitHub Actions  │
│   (CI/CD)       │
│  - Lint/Test    │
│  - Build Image  │
│  - Push to GHCR │
│  - Deploy K8s   │
└────────┬────────┘
         │
         │ Deploy
         ▼
┌─────────────────┐
│  AWS EC2         │
│  (t3.micro)      │
│  ┌─────────────┐ │
│  │   k3s        │ │
│  │ Kubernetes   │ │
│  │  ┌─────────┐ │ │
│  │  │Staging  │ │ │
│  │  └─────────┘ │ │
│  │  ┌─────────┐ │ │
│  │  │Production│ │ │
│  │  └─────────┘ │ │
│  └─────────────┘ │
└────────┬────────┘
         │
         │ NGINX Ingress
         ▼
┌─────────────────┐
│  Public IP      │
│  (HTTP/HTTPS)   │
└─────────────────┘
```

### Components

1. **Application**: Python FastAPI service with `/health` and `/api/v1/example` endpoints
2. **Container Registry**: GitHub Container Registry (GHCR) - avoids ECR costs
3. **Infrastructure**: Single EC2 instance (t3.micro or t3.small) running k3s Kubernetes
4. **Kubernetes**: k3s (lightweight, production-ready Kubernetes distribution)
5. **Ingress**: NGINX Ingress Controller (no AWS Load Balancer costs)
6. **CI/CD**: GitHub Actions workflows for automated testing, building, and deployment
7. **Deployment**: Kubernetes manifests with Kustomize for environment-specific configurations
8. **Observability**: Health checks, application logs via `kubectl`

## 💡 Why k3s Instead of EKS?

### Cost Optimization (Primary Reason)

- **No EKS control plane**: Saves ~$73/month (EKS control plane fee)
- **No ALB costs**: NGINX ingress eliminates ~$16/month load balancer fee
- **Single EC2 instance**: t3.micro (free tier eligible) or t3.small (~$15/month)
- **No managed services overhead**: Everything runs on one instance
- **Estimated monthly cost**: **~$10-15/month** (vs ~$105-110/month with EKS)

### Simplicity for Early-Stage Startups

- **Single node**: Perfect for demos, MVPs, and early-stage startups
- **Easy to understand**: One EC2 instance, one Kubernetes cluster
- **Quick setup**: Infrastructure ready in ~5 minutes
- **Easy teardown**: Delete one EC2 instance to remove everything
- **No complex networking**: Simple VPC, public subnet, no NAT Gateway

### Production Readiness (Appropriate Scale)

- **k3s is production-ready**: Used by thousands of organizations
- **Full Kubernetes API**: 100% compatible with standard Kubernetes
- **Containerd runtime**: Industry-standard container runtime
- **NGINX ingress**: Battle-tested ingress controller
- **Perfect for startup scale**: Handles early traffic easily, clear upgrade path

### Why This Architecture is Appropriate

For **early-stage startups and demos**, this architecture is ideal because:

1. **Cost-effective**: Fits within free tier or minimal budget
2. **Sufficient capacity**: Single node can handle significant traffic for early stage
3. **Professional**: Still uses Kubernetes, CI/CD, proper deployment practices
4. **Scalable path**: Easy to migrate to EKS or multi-node k3s when needed
5. **Learning-friendly**: Simpler to understand and troubleshoot
6. **Portable**: k3s knowledge transfers to any Kubernetes environment

**When to upgrade to EKS**:
- Need high availability (multiple nodes/regions)
- Require AWS service integrations (IRSA, etc.)
- Need managed control plane for compliance
- Traffic exceeds single-node capacity
- Team has budget for managed services

## 🚀 What Problems Does This Solve?

For **startup founders**, this setup provides:

1. **Automated deployments**: Code changes automatically tested and deployed
2. **Environment separation**: Safe testing in staging before production
3. **Ultra-low costs**: Predictable, minimal AWS costs (~$10-15/month)
4. **Professional infrastructure**: Kubernetes-based without enterprise overhead
5. **Easy maintenance**: Simple architecture, well-documented
6. **Clear upgrade path**: Can migrate to EKS when scale requires it

For **DevOps consultants**, this demonstrates:

1. **Cost awareness**: Infrastructure optimized for startup budgets
2. **Kubernetes proficiency**: Full Kubernetes experience with k3s
3. **CI/CD expertise**: GitHub Actions workflows
4. **Documentation skills**: Clear, client-facing documentation
5. **Practical solutions**: Real-world architecture for real budgets

## 📁 Project Structure

```
.
├── app/                    # FastAPI application
│   ├── main.py            # Application code
│   └── __init__.py
├── tests/                 # Unit tests
│   ├── test_main.py
│   └── __init__.py
├── k8s/                   # Kubernetes manifests
│   ├── base/             # Base configurations
│   ├── staging/          # Staging overrides
│   └── production/       # Production overrides
├── terraform/            # Infrastructure as Code
│   ├── main.tf          # EC2 instance with k3s
│   ├── variables.tf     # Variables
│   ├── outputs.tf       # Outputs
│   └── kubernetes.tf     # Kubernetes provider setup
├── .github/
│   └── workflows/       # CI/CD workflows
│       ├── ci.yml       # Lint and test
│       ├── cd.yml       # Build and deploy
│       └── rollback.yml # Manual rollback
├── Dockerfile           # Container image
├── requirements.txt     # Python dependencies
├── README.md           # This file
├── DEPLOYMENT.md       # Setup and deployment guide
└── OPERATIONS.md       # Operations and troubleshooting
```

## 🛠️ Technology Stack

- **Application**: Python 3.11, FastAPI, Uvicorn
- **Container**: Docker (multi-stage builds)
- **Orchestration**: k3s (lightweight Kubernetes)
- **Infrastructure**: Terraform, AWS (VPC, EC2)
- **CI/CD**: GitHub Actions
- **Container Registry**: GitHub Container Registry (GHCR)
- **Load Balancing**: NGINX Ingress Controller
- **Configuration Management**: Kustomize

## 💰 Cost Estimate

**Monthly AWS costs (approximate)**:
- EC2 t3.micro: **$0/month** (free tier) or t3.small: ~$15/month
- EBS storage (20GB): **$0/month** (free tier) or ~$2/month
- Data transfer: Minimal (~$1-2/month)
- **Total**: **~$0-3/month (free tier)** or **~$15-20/month (t3.small)**

**Comparison to EKS**:
- EKS setup: ~$105-110/month
- **k3s setup: ~$10-15/month**
- **Savings: ~$90-100/month (85-90% reduction)**

## 📚 Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)**: Step-by-step setup and deployment instructions
- **[OPERATIONS.md](OPERATIONS.md)**: CI/CD workflows, rollback procedures, troubleshooting
- **[QUICKSTART.md](QUICKSTART.md)**: Quick reference for common tasks

## 🔒 Security Considerations

- **No hardcoded secrets**: Uses Kubernetes Secrets and GitHub Secrets
- **SSH key management**: Terraform generates and manages SSH keys
- **Non-root containers**: Application runs as non-root user
- **Private container registry**: GHCR with access controls
- **Network isolation**: VPC with security groups
- **Encrypted storage**: EBS volumes encrypted

## 🎓 Learning Resources

This project demonstrates:
- Infrastructure as Code with Terraform
- Kubernetes deployment patterns (k3s)
- CI/CD pipeline design
- Cost-optimized cloud architecture
- GitOps-style deployments
- Production-ready application structure

## 📝 License

This is a reference implementation project. Use it as a baseline for your own projects.

## 🤝 Contributing

This is a reference project. Feel free to fork and adapt for your needs.

---

**Built for startups, designed for cost-efficiency, maintained for clarity.**

**Perfect for**: MVPs, demos, early-stage startups, learning Kubernetes, portfolio projects.
