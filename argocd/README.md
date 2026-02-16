# ArgoCD Configuration

This directory contains ArgoCD Application manifests for deploying the Go application using GitOps principles.

## Overview

ArgoCD continuously monitors the Git repository and automatically synchronizes the desired state (Kustomize manifests) to the Kubernetes cluster.

## Files

- `application-dev.yaml` - ArgoCD Application for development environment
- `application-qa.yaml` - ArgoCD Application for QA environment
- `application-prod.yaml` - ArgoCD Application for production environment

## Prerequisites

1. **EKS Cluster**: Deployed using Terraform
2. **kubectl**: Configured to access the cluster
3. **ArgoCD**: Installed on the cluster (can be done via Terraform module)
4. **Git Repository**: Your code pushed to GitHub/GitLab

## Installation

### Option 1: Install ArgoCD via Terraform (Recommended)

ArgoCD can be installed automatically when deploying infrastructure. Uncomment the ArgoCD module in your environment's `main.tf`.

### Option 2: Install ArgoCD Manually

```bash
# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

## Access ArgoCD UI

### Get Initial Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

### Access via Port Forward

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open: https://localhost:8080
- Username: `admin`
- Password: (from previous step)

### Access via LoadBalancer (if configured)

```bash
kubectl get svc argocd-server -n argocd
```

Use the EXTERNAL-IP to access ArgoCD.

## Deploy Application

### 1. Update Git Repository URL

Edit the Application YAML files and replace `<YOUR-ORG>/<YOUR-REPO>` with your actual Git repository:

```yaml
source:
  repoURL: https://github.com/your-org/your-repo
```

### 2. Update IRSA Annotation

After Terraform completes, update the ServiceAccount with the IAM role ARN:

```bash
# Get IAM role ARN from Terraform
cd terraform/environments/dev  # or qa/prod
terraform output iam_role_arn

# Update k8s/base/serviceaccount.yaml
```

Edit `k8s/base/serviceaccount.yaml`:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-serviceaccount
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME
```

Commit and push the changes.

### 3. Apply ArgoCD Application

```bash
# For Development
kubectl apply -f argocd/application-dev.yaml

# For QA
kubectl apply -f argocd/application-qa.yaml

# For Production
kubectl apply -f argocd/application-prod.yaml
```

### 4. Verify Deployment

```bash
# Check ArgoCD Application status
kubectl get applications -n argocd

# Check application pods
kubectl get pods -n default

# View ArgoCD Application details
kubectl describe application go-app-dev -n argocd
```

## ArgoCD Application Features

### Automated Sync
- **prune: true** - Removes resources deleted from Git
- **selfHeal: true** - Reverts manual changes to Git state
- **allowEmpty: false** - Prevents syncing empty directories

### Sync Options
- **CreateNamespace=true** - Automatically creates target namespace
- **PrunePropagationPolicy=foreground** - Ensures proper deletion order
- **PruneLast=true** - Prunes resources after new ones are healthy

### Retry Policy
- Automatically retries failed syncs
- Exponential backoff (5s, 10s, 20s, 40s, 3m)
- Maximum 5 retry attempts

## GitOps Workflow

1. **Developer pushes code** to Git repository
2. **CI/CD pipeline** builds Docker image and updates Kustomize manifest
3. **ArgoCD detects** manifest changes in Git
4. **ArgoCD syncs** changes to Kubernetes cluster
5. **Application updates** automatically

## Monitoring

### View Sync Status

```bash
# List all applications
kubectl get applications -n argocd

# Watch application status
kubectl get application go-app-dev -n argocd -w

# View detailed status
argocd app get go-app-dev
```

### View Application Logs

```bash
# ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Application controller logs
kubectl logs -n argocd deployment/argocd-application-controller
```

## Troubleshooting

### Application Not Syncing

```bash
# Check application status
kubectl describe application go-app-dev -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Manually trigger sync
argocd app sync go-app-dev
```

### Authentication Issues

```bash
# Reset admin password
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "'$(htpasswd -bnBC 10 "" YOUR_PASSWORD | tr -d ':\n')'"}}'

# Restart ArgoCD server
kubectl rollout restart deployment argocd-server -n argocd
```

### Sync Failures

Common causes:
- Invalid Kustomize manifests
- Missing IRSA annotation
- Insufficient IAM permissions
- Resource conflicts

Check:
```bash
# Validate Kustomize locally
kustomize build k8s/overlays/dev

# Check pod events
kubectl get events -n default --sort-by='.lastTimestamp'
```

## Best Practices

1. **Use Git as Single Source of Truth**: Never manually edit resources in the cluster
2. **Enable Auto-Sync**: Let ArgoCD automatically deploy changes
3. **Enable Self-Heal**: Prevent configuration drift
4. **Use Separate Applications**: One per environment
5. **Monitor Sync Status**: Set up alerts for failed syncs
6. **Review Changes**: Use ArgoCD UI to review before syncing
7. **Use App of Apps Pattern**: For managing multiple applications

## Security Considerations

1. **RBAC**: Configure ArgoCD RBAC for team access
2. **SSO**: Integrate with your identity provider
3. **Secrets Management**: Use sealed-secrets or external-secrets
4. **Network Policies**: Restrict ArgoCD network access
5. **Audit Logs**: Enable and monitor ArgoCD audit logs

## CLI Installation (Optional)

```bash
# Install ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Login to ArgoCD
argocd login localhost:8080

# List applications
argocd app list

# Sync application
argocd app sync go-app-dev
```

## Next Steps

1. Configure notifications (Slack, email)
2. Set up ArgoCD Image Updater for automatic image updates
3. Implement progressive delivery with Argo Rollouts
4. Configure ArgoCD ApplicationSets for multi-cluster deployments
5. Set up monitoring with Prometheus and Grafana
