# Infrastructure Setup Guide

This guide provides step-by-step instructions for deploying the complete DevOps infrastructure for the Go application on AWS EKS using GitOps principles.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Setup Steps](#setup-steps)
  - [1. Configure AWS Credentials](#1-configure-aws-credentials)
  - [2. Deploy Infrastructure with Terraform](#2-deploy-infrastructure-with-terraform)
  - [3. Configure kubectl Access](#3-configure-kubectl-access)
  - [4. Access ArgoCD](#4-access-argocd)
  - [5. Configure GitHub Actions Secrets](#5-configure-github-actions-secrets)
  - [6. Deploy Application](#6-deploy-application)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Prerequisites

Before starting, ensure you have the following tools installed:

### Required Tools

1. **AWS CLI** (v2.x or later)
   ```bash
   # Installation
   # macOS
   brew install awscli
   
   # Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   
   # Windows
   # Download and run: https://awscli.amazonaws.com/AWSCLIV2.msi
   
   # Verify installation
   aws --version
   ```

2. **Terraform** (v1.5.x or later)
   ```bash
   # Installation
   # macOS
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
   unzip terraform_1.5.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   
   # Windows
   # Download from: https://www.terraform.io/downloads
   
   # Verify installation
   terraform version
   ```

3. **kubectl** (v1.28.x or later)
   ```bash
   # Installation
   # macOS
   brew install kubectl
   
   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   
   # Windows
   # Download from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
   
   # Verify installation
   kubectl version --client
   ```

4. **Kustomize** (v5.x or later)
   ```bash
   # Installation
   # macOS
   brew install kustomize
   
   # Linux
   curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
   sudo mv kustomize /usr/local/bin/
   
   # Windows
   # Download from: https://github.com/kubernetes-sigs/kustomize/releases
   
   # Verify installation
   kustomize version
   ```

### AWS Account Requirements

- AWS account with appropriate permissions
- IAM user or role with permissions to create:
  - VPC, Subnets, Internet Gateway, NAT Gateway
  - EKS Cluster and Node Groups
  - IAM Roles and Policies
  - KMS Keys
  - Security Groups
- Sufficient service quotas for:
  - VPCs (at least 1)
  - Elastic IPs (at least 2 for NAT Gateways)
  - EKS Clusters (at least 1)
  - EC2 instances (at least 6 t3.medium instances)

## Architecture Overview

The infrastructure consists of:

- **VPC**: Multi-AZ VPC with public and private subnets
- **EKS Cluster**: Kubernetes cluster version 1.28 with managed node groups
- **ArgoCD**: GitOps continuous delivery tool
- **IRSA**: IAM Roles for Service Accounts for secure AWS access
- **CI/CD Pipeline**: GitHub Actions for automated builds and deployments

## Setup Steps

### 1. Configure AWS Credentials

Configure your AWS credentials for Terraform to use:

```bash
# Option 1: Using AWS CLI configure
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
# Enter your default output format (json)

# Option 2: Using environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Verify credentials
aws sts get-caller-identity
```

### 2. Deploy Infrastructure with Terraform

Choose your target environment (dev, qa, or prod) and deploy:

#### For Development Environment

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review the execution plan
terraform plan

# Apply the configuration
terraform apply

# Type 'yes' when prompted to confirm
```

#### For QA Environment

```bash
cd terraform/environments/qa

terraform init
terraform plan
terraform apply
```

#### For Production Environment

```bash
cd terraform/environments/prod

terraform init
terraform plan
terraform apply
```

**Note**: The deployment takes approximately 15-20 minutes to complete.

#### Terraform Outputs

After successful deployment, Terraform will output important values:

```bash
# View all outputs
terraform output

# View specific output
terraform output cluster_endpoint
terraform output cluster_name
terraform output iam_role_arn
```

Save these outputs as you'll need them for subsequent steps.

### 3. Configure kubectl Access

Configure kubectl to access your EKS cluster:

```bash
# Get cluster name from Terraform output
CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION="us-east-1"  # Use your region

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

# Verify access
kubectl get nodes
kubectl get namespaces
```

Expected output:
```
NAME                                       STATUS   ROLES    AGE   VERSION
ip-10-0-10-xxx.ec2.internal               Ready    <none>   5m    v1.28.x
ip-10-0-11-xxx.ec2.internal               Ready    <none>   5m    v1.28.x
ip-10-0-10-yyy.ec2.internal               Ready    <none>   5m    v1.28.x
```

### 4. Access ArgoCD

ArgoCD is automatically deployed by Terraform. Follow these steps to access it:

#### Get ArgoCD Admin Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

#### Access ArgoCD UI

**Option 1: Port Forward (Recommended for testing)**

```bash
# Forward ArgoCD server port to localhost
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access in browser: https://localhost:8080
# Username: admin
# Password: (from previous step)
```

**Option 2: LoadBalancer (Production)**

```bash
# Get LoadBalancer URL
kubectl get svc argocd-server -n argocd

# Access using the EXTERNAL-IP in browser
# https://<EXTERNAL-IP>
```

**Option 3: Ingress (Production with custom domain)**

Configure an Ingress resource with your domain and TLS certificate.

#### Change Admin Password (Recommended)

```bash
# Login to ArgoCD CLI
argocd login localhost:8080 --username admin --password <initial-password>

# Change password
argocd account update-password
```

### 5. Configure GitHub Actions Secrets

Add the following secrets to your GitHub repository:

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add the following secrets:

| Secret Name | Description | How to Get |
|------------|-------------|------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username | Your Docker Hub account username |
| `DOCKERHUB_TOKEN` | Docker Hub access token | Create at https://hub.docker.com/settings/security |

#### Creating Docker Hub Access Token

1. Log in to Docker Hub
2. Go to **Account Settings** → **Security**
3. Click **New Access Token**
4. Give it a description (e.g., "GitHub Actions")
5. Select **Read, Write, Delete** permissions
6. Click **Generate**
7. Copy the token (you won't be able to see it again)

### 6. Deploy Application

#### Update IRSA Annotation

Update the ServiceAccount with the IAM role ARN from Terraform:

```bash
# Get IAM role ARN
cd terraform/environments/<your-env>
IAM_ROLE_ARN=$(terraform output -raw iam_role_arn)

# Update the serviceaccount patch file
cd ../../../k8s/overlays/<your-env>
sed -i "s|arn:aws:iam::.*:role/.*|$IAM_ROLE_ARN|g" serviceaccount-patch.yaml

# Commit the change
git add serviceaccount-patch.yaml
git commit -m "Update IRSA role ARN for <your-env>"
git push
```

#### Deploy ArgoCD Application

```bash
# Update the ArgoCD Application manifest with your repository URL
cd argocd
# Edit application-<env>.yaml and update the repoURL

# Apply the ArgoCD Application
kubectl apply -f application-<env>.yaml -n argocd

# Verify the application is synced
kubectl get applications -n argocd
argocd app get go-app
```

#### Trigger CI/CD Pipeline

1. Go to your GitHub repository
2. Navigate to **Actions** tab
3. Select **CI/CD Pipeline** workflow
4. Click **Run workflow**
5. Select your target environment (dev/staging/production)
6. Click **Run workflow**

The pipeline will:
- Run security scans on code and infrastructure
- Build and test the Go application
- Build and push Docker image
- Scan the Docker image for vulnerabilities
- Update the Kustomize manifest with new image tag
- ArgoCD will automatically sync the changes to the cluster

## Verification

### Verify Infrastructure

```bash
# Check EKS cluster
aws eks describe-cluster --name <cluster-name> --region <region>

# Check nodes
kubectl get nodes -o wide

# Check namespaces
kubectl get namespaces
```

### Verify ArgoCD

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD applications
kubectl get applications -n argocd

# Check application sync status
argocd app get go-app
```

### Verify Application Deployment

```bash
# Check application pods
kubectl get pods -n default

# Check services
kubectl get svc -n default

# Check HPA
kubectl get hpa -n default

# Check pod logs
kubectl logs -l app=go-app -n default

# Test the application
kubectl port-forward svc/go-app-service 8080:80
curl http://localhost:8080/?name=World
# Expected: Hello World
```

### Verify IRSA

```bash
# Check ServiceAccount annotation
kubectl get sa app-serviceaccount -n default -o yaml | grep eks.amazonaws.com/role-arn

# Check pod environment variables
kubectl exec -it <pod-name> -n default -- env | grep AWS
```

## Troubleshooting

### EKS Cluster Creation Fails

**Issue**: Terraform fails to create EKS cluster

**Solutions**:
- Check AWS service quotas: `aws service-quotas list-service-quotas --service-code eks`
- Verify IAM permissions for your AWS user/role
- Check if VPC CIDR conflicts with existing VPCs
- Review Terraform error messages for specific issues

### kubectl Cannot Connect to Cluster

**Issue**: `kubectl get nodes` returns connection error

**Solutions**:
```bash
# Update kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region <region>

# Verify AWS credentials
aws sts get-caller-identity

# Check cluster endpoint
aws eks describe-cluster --name <cluster-name> --query cluster.endpoint
```

### ArgoCD Application Not Syncing

**Issue**: ArgoCD shows "OutOfSync" status

**Solutions**:
```bash
# Check application status
argocd app get go-app

# Manual sync
argocd app sync go-app

# Check for errors
kubectl describe application go-app -n argocd

# Verify Git repository access
argocd repo list
```

### Pods Not Starting

**Issue**: Pods stuck in Pending or CrashLoopBackOff

**Solutions**:
```bash
# Check pod status
kubectl describe pod <pod-name> -n default

# Check pod logs
kubectl logs <pod-name> -n default

# Check events
kubectl get events -n default --sort-by='.lastTimestamp'

# Common issues:
# - Insufficient resources: Check node capacity
# - Image pull errors: Verify Docker Hub credentials
# - IRSA issues: Check ServiceAccount annotation
```

### GitHub Actions Workflow Fails

**Issue**: CI/CD pipeline fails

**Solutions**:
- Check GitHub Actions logs for specific error
- Verify GitHub secrets are set correctly
- Ensure Docker Hub credentials are valid
- Check if image name format is correct
- Verify Kustomize manifest syntax

## Cleanup

To destroy all infrastructure and avoid AWS charges:

```bash
# Delete ArgoCD applications first
kubectl delete application go-app -n argocd

# Wait for resources to be cleaned up
kubectl get all -n default

# Destroy Terraform infrastructure
cd terraform/environments/<your-env>
terraform destroy

# Type 'yes' when prompted to confirm
```

**Warning**: This will permanently delete all resources including:
- EKS cluster and node groups
- VPC and all networking components
- IAM roles and policies
- Any data stored in the cluster

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kustomize Documentation](https://kustomize.io/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review application logs: `kubectl logs -l app=go-app`
3. Check ArgoCD UI for sync status
4. Review GitHub Actions workflow logs
