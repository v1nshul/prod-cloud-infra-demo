# Kubernetes provider configuration for k3s
# Note: This requires manual setup after EC2 instance is created
# The kubeconfig must be copied from the instance first

# Data source to get k3s instance details
data "aws_instance" "k3s" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-k3s"]
  }
  depends_on = [aws_instance.k3s]
}

# Kubernetes provider - configured via environment or kubeconfig file
# After initial setup, use: export KUBECONFIG=~/.kube/k3s-config
provider "kubernetes" {
  config_path = var.kubeconfig_path
  # Alternatively, configure via host, token, and ca_certificate if available
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# Create namespaces (if not already created by k3s install script)
resource "kubernetes_namespace" "staging" {
  count = var.create_namespaces ? 1 : 0
  
  metadata {
    name = "prod-cloud-infra-demo-staging"
    labels = {
      name        = "prod-cloud-infra-demo-staging"
      managed-by  = "terraform"
      environment = "staging"
    }
  }
}

resource "kubernetes_namespace" "production" {
  count = var.create_namespaces ? 1 : 0
  
  metadata {
    name = "prod-cloud-infra-demo"
    labels = {
      name        = "prod-cloud-infra-demo"
      managed-by  = "terraform"
      environment = "production"
    }
  }
}

# Note: NGINX Ingress Controller is installed via the EC2 user_data script
# No need to manage it via Terraform, but we can verify it exists
