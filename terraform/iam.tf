# k3s doesn't require complex IAM roles like EKS
# The EC2 instance uses the default instance profile
# No additional IAM resources needed for k3s

# Note: If you need to access other AWS services from k3s pods,
# you can attach IAM roles to the EC2 instance or use IRSA (more complex)
