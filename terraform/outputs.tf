output "k3s_instance_id" {
  description = "EC2 instance ID running k3s"
  value       = aws_instance.k3s.id
}

output "k3s_public_ip" {
  description = "Public IP address of k3s instance"
  value       = aws_eip.k3s.public_ip
}

output "k3s_public_dns" {
  description = "Public DNS name of k3s instance"
  value       = aws_instance.k3s.public_dns
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "ssh_private_key_path" {
  description = "Path to SSH private key for EC2 access"
  value       = "${path.module}/k3s_private_key.pem"
  sensitive   = true
}

output "configure_kubectl" {
  description = "Instructions to configure kubectl for k3s"
  value       = <<-EOT
    # Copy kubeconfig from k3s instance:
    scp -i ${path.module}/k3s_private_key.pem ec2-user@${aws_eip.k3s.public_ip}:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config
    
    # Update server URL in kubeconfig:
    sed -i 's/127.0.0.1/${aws_eip.k3s.public_ip}/g' ~/.kube/k3s-config
    
    # Set KUBECONFIG:
    export KUBECONFIG=~/.kube/k3s-config
    
    # Or merge with existing config:
    KUBECONFIG=~/.kube/config:~/.kube/k3s-config kubectl config view --flatten > ~/.kube/config_merged && mv ~/.kube/config_merged ~/.kube/config
  EOT
}

output "access_instructions" {
  description = "Instructions to access the k3s cluster"
  value       = <<-EOT
    SSH to k3s instance:
    ssh -i ${path.module}/k3s_private_key.pem ec2-user@${aws_eip.k3s.public_ip}
    
    Access k3s API:
    kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get nodes
    
    Application will be accessible via:
    http://${aws_eip.k3s.public_ip} (after NGINX ingress is configured)
  EOT
}
