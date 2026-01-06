variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-2"  # London - cost-effective region
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "prod-cloud-infra-demo"
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "EC2 instance type for k3s cluster"
  type        = string
  default     = "t3.micro"  # Free tier eligible, or t3.small for better performance
}

variable "disk_size" {
  description = "Root disk size in GB"
  type        = number
  default     = 20  # Free tier eligible
}

variable "github_username" {
  description = "GitHub username for container registry"
  type        = string
  default     = ""  # Set via terraform.tfvars or environment variable
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file for k3s (set after initial setup)"
  type        = string
  default     = "~/.kube/k3s-config"
}

variable "create_namespaces" {
  description = "Whether to create namespaces via Terraform (namespaces are created by k3s install script)"
  type        = bool
  default     = false
}
