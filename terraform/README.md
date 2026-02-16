# Terraform Infrastructure

This directory contains modular Terraform code to provision AWS infrastructure for the Go application across multiple environments.

## Structure

```
terraform/
├── modules/                    # Reusable Terraform modules
│   ├── vpc/                   # VPC module - networking infrastructure
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── eks/                   # EKS module - Kubernetes cluster
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── irsa/                  # IRSA module - IAM roles for service accounts
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/              # Environment-specific configurations
    ├── dev/                   # Development environment
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── terraform.tfvars
    ├── qa/                    # QA/Staging environment
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── terraform.tfvars
    └── prod/                  # Production environment
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── terraform.tfvars
```

## Environments

### Development (dev)
- **Purpose**: Development and testing
- **Nodes**: 1-3 nodes (t3.small)
- **VPC CIDR**: 10.0.0.0/16
- **Cost**: ~$50-80/month

### QA (qa)
- **Purpose**: Quality assurance and staging
- **Nodes**: 2-4 nodes (t3.medium)
- **VPC CIDR**: 10.1.0.0/16
- **Cost**: ~$100-150/month

### Production (prod)
- **Purpose**: Production workloads
- **Nodes**: 2-6 nodes (t3.medium)
- **VPC CIDR**: 10.2.0.0/16
- **High Availability**: Multi-AZ with auto-scaling
- **Cost**: ~$200-250/month

## Modules

### VPC Module
Creates a multi-AZ VPC with:
- Public and private subnets across 2 availability zones
- Internet Gateway for public subnets
- NAT Gateways (one per AZ) for high availability
- Route tables for public and private subnets
- Required EKS tags for subnet discovery

### EKS Module
Provisions an EKS cluster with:
- EKS control plane with version 1.28
- Managed node group with auto-scaling (2-6 nodes)
- KMS encryption for secrets
- Cluster logging enabled
- OIDC provider for IRSA
- EKS addons (vpc-cni, coredns, kube-proxy)
- Security groups with least privilege access

### IRSA Module
Configures IAM Roles for Service Accounts:
- IAM role with OIDC trust policy
- Policies for AWS service access (S3, DynamoDB)
- Service account annotation for Kubernetes

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- AWS account with permissions to create VPC, EKS, IAM resources

## Usage

### Deploy Development Environment

1. **Navigate to dev environment**
   ```bash
   cd terraform/environments/dev
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Review and customize variables**
   Edit `terraform.tfvars` to match your requirements

4. **Plan the infrastructure**
   ```bash
   terraform plan
   ```

5. **Apply the configuration**
   ```bash
   terraform apply
   ```

6. **Configure kubectl**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name go-app-dev
   ```

### Deploy QA Environment

```bash
cd terraform/environments/qa
terraform init
terraform plan
terraform apply
aws eks update-kubeconfig --region us-east-1 --name go-app-qa
```

### Deploy Production Environment

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
aws eks update-kubeconfig --region us-east-1 --name go-app-prod
```

## State Management

For production use, configure S3 backend for remote state storage. Uncomment the backend configuration in each environment's `main.tf`:

```hcl
backend "s3" {
  bucket         = "your-terraform-state-bucket"
  key            = "prod/terraform.tfstate"  # Use env-specific keys
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
}
```

Create the S3 bucket and DynamoDB table first:
```bash
aws s3 mb s3://your-terraform-state-bucket
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

## Outputs

After applying, Terraform will output:
- `cluster_endpoint` - EKS API server endpoint
- `cluster_name` - Name of the EKS cluster
- `oidc_provider_arn` - ARN of OIDC provider for IRSA
- `iam_role_arn` - IAM role ARN for application pods
- `vpc_id` - VPC ID
- `private_subnet_ids` - Private subnet IDs
- `configure_kubectl` - Command to configure kubectl

## Security Features

- **Network Isolation**: Worker nodes in private subnets
- **Encryption**: KMS encryption for EKS secrets
- **Logging**: All EKS control plane logs enabled
- **IRSA**: No static AWS credentials in pods
- **Least Privilege**: Minimal IAM permissions

## Cost Considerations

This infrastructure will incur AWS costs:
- EKS cluster: ~$0.10/hour
- EC2 instances (3x t3.medium): ~$0.125/hour
- NAT Gateways (2): ~$0.09/hour
- Data transfer charges

**Estimated monthly cost: ~$200-250**

## Cleanup

To destroy resources for a specific environment:

```bash
# Development
cd terraform/environments/dev
terraform destroy

# QA
cd terraform/environments/qa
terraform destroy

# Production
cd terraform/environments/prod
terraform destroy
```

**Warning**: This will delete all resources including the EKS cluster and VPC for that environment.

## Environment Comparison

| Feature | Dev | QA | Prod |
|---------|-----|-----|------|
| Node Type | t3.small | t3.medium | t3.medium |
| Min Nodes | 1 | 2 | 2 |
| Max Nodes | 3 | 4 | 6 |
| Desired Nodes | 2 | 2 | 3 |
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| Monthly Cost | ~$50-80 | ~$100-150 | ~$200-250 |
| Purpose | Development | Testing/Staging | Production |

## Customization

### Changing Node Instance Types
Edit `terraform.tfvars`:
```hcl
node_instance_types = ["t3.large"]
```

### Adjusting Auto-Scaling
Edit `terraform.tfvars`:
```hcl
node_min_size = 3
node_max_size = 10
node_desired_size = 5
```

### Adding AWS Service Permissions
Edit `modules/irsa/main.tf` to add additional IAM policies for your application.

## Troubleshooting

### Issue: Terraform can't find modules
**Solution**: Run `terraform init` to download module dependencies

### Issue: AWS credentials not configured
**Solution**: Configure AWS CLI with `aws configure` or set environment variables

### Issue: Insufficient permissions
**Solution**: Ensure your AWS user/role has permissions for VPC, EKS, IAM, and KMS

### Issue: Cluster creation timeout
**Solution**: EKS cluster creation takes 10-15 minutes. Be patient or increase timeout in provider configuration.
