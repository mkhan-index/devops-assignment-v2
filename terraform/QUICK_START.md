# Terraform Quick Start Guide

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0 installed
- Appropriate AWS permissions (VPC, EKS, IAM, KMS)

## Deploy an Environment

### 1. Choose Your Environment

```bash
# Development
cd terraform/environments/dev

# QA
cd terraform/environments/qa

# Production
cd terraform/environments/prod
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review Configuration

Check `terraform.tfvars` for environment-specific settings:
- Node sizes
- Node counts
- VPC CIDR
- AWS region

### 4. Plan Changes

```bash
terraform plan
```

Review the planned changes carefully.

### 5. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted.

**Note**: EKS cluster creation takes 10-15 minutes.

### 6. Configure kubectl

After successful deployment:

```bash
# Development
aws eks update-kubeconfig --region us-east-1 --name go-app-dev

# QA
aws eks update-kubeconfig --region us-east-1 --name go-app-qa

# Production
aws eks update-kubeconfig --region us-east-1 --name go-app-prod
```

### 7. Verify Cluster

```bash
kubectl get nodes
kubectl get pods -A
```

## Important Outputs

After `terraform apply`, note these outputs:
- `cluster_endpoint` - EKS API endpoint
- `iam_role_arn` - IAM role for IRSA (needed for Kustomize)
- `configure_kubectl` - Command to configure kubectl

## Update Kustomize with IRSA Role

After Terraform completes, update your Kustomize ServiceAccount:

```bash
# Get the IAM role ARN from Terraform output
terraform output iam_role_arn

# Update k8s/base/serviceaccount.yaml with the ARN
```

## Common Commands

```bash
# View current state
terraform show

# List all resources
terraform state list

# View specific output
terraform output cluster_name

# Refresh state
terraform refresh

# Destroy environment
terraform destroy
```

## Troubleshooting

### Issue: "Error: configuring Terraform AWS Provider"
**Solution**: Check AWS credentials with `aws sts get-caller-identity`

### Issue: "Error creating EKS Cluster: LimitExceeded"
**Solution**: Check AWS service quotas for EKS and VPC

### Issue: "Error: Kubernetes cluster unreachable"
**Solution**: Run `aws eks update-kubeconfig` command from outputs

### Issue: State lock error
**Solution**: If using S3 backend, check DynamoDB table for stuck locks

## Best Practices

1. **Always run `terraform plan` before `apply`**
2. **Use separate AWS accounts for prod vs non-prod**
3. **Enable S3 backend for production** (see main README)
4. **Tag all resources appropriately** (already configured)
5. **Review security group rules** before production deployment
6. **Set up CloudWatch alarms** for production clusters
7. **Enable AWS Config** for compliance tracking

## Cost Management

Monitor costs in AWS Cost Explorer:
- Filter by tag: `Environment=dev/qa/prod`
- Filter by tag: `Project=go-app`

Expected monthly costs:
- Dev: $50-80
- QA: $100-150
- Prod: $200-250

## Next Steps

After infrastructure is deployed:
1. Deploy application using Kustomize
2. Set up ArgoCD for GitOps
3. Configure CI/CD pipeline
4. Set up monitoring and logging
5. Configure backups and disaster recovery
