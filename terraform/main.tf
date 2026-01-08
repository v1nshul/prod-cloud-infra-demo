terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }

  # Optional: Use S3 backend for state management (configure separately)
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "prod-cloud-infra-demo/terraform.tfstate"
  #   region = "eu-west-2"
  # }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "prod-cloud-infra-demo"
      ManagedBy   = "terraform"
      Environment = var.environment
      Owner       = var.owner != "" ? var.owner : var.github_username
    }
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC - Single AZ to minimize costs
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway (no NAT Gateway to save costs)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnet (single AZ for cost optimization)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# Route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group for k3s EC2 instance
resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-k3s-sg"
  description = "Security group for k3s Kubernetes cluster"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # HTTP for NGINX ingress
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS for NGINX ingress
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # k3s API server
  ingress {
    description = "k3s API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict in production
  }

  # All outbound traffic
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-k3s-sg"
  }
}

# Generate SSH key pair for EC2 access
resource "tls_private_key" "k3s_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally (for kubectl access)
resource "local_file" "private_key" {
  content         = tls_private_key.k3s_ssh.private_key_pem
  filename        = "${path.module}/k3s_private_key.pem"
  file_permission = "0600"
  
  # Ensure directory exists
  directory_permission = "0755"
}

# EC2 Key Pair
resource "aws_key_pair" "k3s" {
  key_name   = var.key_pair_name != "" ? var.key_pair_name : "${var.project_name}-k3s-key"
  public_key = tls_private_key.k3s_ssh.public_key_openssh

  tags = {
    Name = var.key_pair_name != "" ? var.key_pair_name : "${var.project_name}-k3s-key"
  }
}

# k3s installation script
locals {
  k3s_install_script = <<-EOF
#!/bin/bash
set -e

# Update system
sudo dnf update -y

# Install required packages
sudo dnf install -y curl wget git

# Install k3s with containerd (disable traefik, we'll use NGINX)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --disable traefik" sh -

# Wait for k3s to be ready
echo "Waiting for k3s to start..."
sleep 30
sudo systemctl status k3s --no-pager || true

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Wait for k3s API to be ready
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
until kubectl get nodes; do
  echo "Waiting for k3s API..."
  sleep 5
done

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Wait for NGINX Ingress to be ready (with timeout)
echo "Waiting for NGINX Ingress Controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s || echo "NGINX Ingress may still be starting"

# Create namespaces
kubectl create namespace prod-cloud-infra-demo --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod-cloud-infra-demo-staging --dry-run=client -o yaml | kubectl apply -f -

# Output kubeconfig location for reference
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "k3s kubeconfig location: /etc/rancher/k3s/k3s.yaml"
echo "To access from local machine, copy kubeconfig and update server URL to: https://$PUBLIC_IP:6443"
echo "k3s installation completed!"
EOF
}

# EC2 Instance for k3s
resource "aws_instance" "k3s" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.k3s.key_name
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.k3s.id]

  user_data = local.k3s_install_script

  root_block_device {
    volume_type = "gp3"
    volume_size = var.disk_size
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-k3s"
  }

  # Ensure instance is running before proceeding
  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP for stable access (optional but recommended)
resource "aws_eip" "k3s" {
  domain = "vpc"
  instance = aws_instance.k3s.id

  tags = {
    Name = "${var.project_name}-k3s-eip"
  }

  depends_on = [aws_instance.k3s]
}
