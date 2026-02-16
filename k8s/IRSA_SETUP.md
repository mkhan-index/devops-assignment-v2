# IRSA (IAM Roles for Service Accounts) Setup Guide

## Overview

IRSA allows Kubernetes pods to assume AWS IAM roles without needing static credentials. This is configured through annotations on the ServiceAccount.

## Prerequisites

1. EKS cluster deployed with OIDC provider enabled (done via Terraform)
2. IAM role created with OIDC trust policy (done via Terraform)
3. Terraform outputs available

## Setup Steps

### Step 1: Deploy Infrastructure with Terraform

Deploy your environment-specific infrastructure:

```bash
# For Development
cd terraform/environments/dev
terraform init
terraform apply

# For QA
cd terraform/environments/qa
terraform init
terraform apply

# For Production
cd terraform/environments/prod
terraform init
terraform apply
```

### Step 2: Get IAM Role ARN

After Terraform completes, get the IAM role ARN:

```bash
# Development
cd terraform/environments/dev
terraform output iam_role_arn

# QA
cd terraform/environments/qa
terraform output iam_role_arn

# Production
cd terraform/environments/prod
terraform output iam_role_arn
```

Example output:
```
arn:aws:iam::123456789012:role/go-app-dev-app-role
```

### Step 3: Update ServiceAccount Patches

Update the appropriate overlay's serviceaccount-patch.yaml file:

**For Development** (`k8s/overlays/dev/serviceaccount-patch.yaml`):
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-serviceaccount
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/go-app-dev-app-role
```

**For QA** (`k8s/overlays/staging/serviceaccount-patch.yaml`):
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-serviceaccount
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/go-app-qa-app-role
```

**For Production** (`k8s/overlays/production/serviceaccount-patch.yaml`):
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-serviceaccount
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/go-app-prod-app-role
```

### Step 4: Verify Kustomize Build

Test that Kustomize builds correctly with the annotation:

```bash
# Development
kustomize build k8s/overlays/dev | grep -A 5 "kind: ServiceAccount"

# QA
kustomize build k8s/overlays/staging | grep -A 5 "kind: ServiceAccount"

# Production
kustomize build k8s/overlays/production | grep -A 5 "kind: ServiceAccount"
```

You should see the `eks.amazonaws.com/role-arn` annotation with your IAM role ARN.

### Step 5: Commit and Push Changes

```bash
git add k8s/overlays/*/serviceaccount-patch.yaml
git commit -m "Update IRSA annotations with IAM role ARNs"
git push origin main
```

### Step 6: Deploy via ArgoCD

If using ArgoCD, it will automatically detect the changes and sync. Otherwise, apply manually:

```bash
# Development
kubectl apply -k k8s/overlays/dev

# QA
kubectl apply -k k8s/overlays/staging

# Production
kubectl apply -k k8s/overlays/production
```

## Verification

### Verify ServiceAccount Annotation

```bash
kubectl get serviceaccount app-serviceaccount -o yaml
```

Look for the annotation:
```yaml
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/go-app-dev-app-role
```

### Verify Pod Has AWS Credentials

```bash
# Get a pod name
POD_NAME=$(kubectl get pods -l app=go-app -o jsonpath='{.items[0].metadata.name}')

# Check environment variables
kubectl exec $POD_NAME -- env | grep AWS

# You should see:
# AWS_ROLE_ARN=arn:aws:iam::123456789012:role/go-app-dev-app-role
# AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
```

### Test AWS Access from Pod

```bash
# Install AWS CLI in the pod (if not already present)
kubectl exec $POD_NAME -- aws sts get-caller-identity

# You should see the assumed role identity
```

## Troubleshooting

### Issue: Pod doesn't have AWS credentials

**Check:**
1. ServiceAccount has the correct annotation
2. Pod is using the correct ServiceAccount
3. OIDC provider is configured in EKS
4. IAM role trust policy includes the correct OIDC provider

**Verify:**
```bash
# Check pod's service account
kubectl get pod $POD_NAME -o jsonpath='{.spec.serviceAccountName}'

# Check if pod has the token volume
kubectl get pod $POD_NAME -o yaml | grep -A 10 "volumes:"
```

### Issue: Access Denied errors

**Check:**
1. IAM role has the necessary permissions
2. IAM role trust policy is correct
3. Service account name matches the trust policy

**Verify IAM role:**
```bash
aws iam get-role --role-name go-app-dev-app-role
aws iam list-attached-role-policies --role-name go-app-dev-app-role
```

### Issue: OIDC provider not found

**Check:**
```bash
# Get OIDC provider ARN from Terraform
cd terraform/environments/dev
terraform output oidc_provider_arn

# Verify it exists in AWS
aws iam list-open-id-connect-providers
```

## IAM Role Trust Policy

The IAM role created by Terraform has a trust policy that looks like this:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": "system:serviceaccount:default:app-serviceaccount",
          "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

Key points:
- **Federated Principal**: OIDC provider ARN
- **Condition**: Matches specific namespace and service account name
- **Action**: AssumeRoleWithWebIdentity

## Security Best Practices

1. **Least Privilege**: Grant only necessary permissions to the IAM role
2. **Separate Roles**: Use different IAM roles for different environments
3. **Audit**: Enable CloudTrail to audit role assumptions
4. **Rotate**: Regularly review and update IAM policies
5. **Monitor**: Set up CloudWatch alarms for unusual activity

## Additional Resources

- [AWS IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [EKS Best Practices - IAM](https://aws.github.io/aws-eks-best-practices/security/docs/iam/)
- [Kubernetes Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
