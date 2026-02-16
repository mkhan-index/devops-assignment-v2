# Kustomize Customization Guide

This guide explains how to customize Kubernetes deployments using Kustomize without modifying base configuration files.

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Base Configuration](#base-configuration)
- [Overlay Customization](#overlay-customization)
- [Common Customizations](#common-customizations)
- [Best Practices](#best-practices)
- [Validation](#validation)
- [Examples](#examples)

## Overview

Kustomize allows you to customize Kubernetes manifests without modifying the original files. This approach:

- Keeps base configurations clean and reusable
- Enables environment-specific customizations
- Maintains a clear separation between base and environment-specific settings
- Supports GitOps workflows with declarative configuration

## Directory Structure

```
k8s/
├── base/                          # Base configuration (shared across environments)
│   ├── deployment.yaml           # Application deployment
│   ├── service.yaml              # Service definition
│   ├── serviceaccount.yaml       # ServiceAccount for IRSA
│   ├── hpa.yaml                  # Horizontal Pod Autoscaler
│   └── kustomization.yaml        # Base kustomization file
│
└── overlays/                      # Environment-specific customizations
    ├── dev/                       # Development environment
    │   ├── kustomization.yaml
    │   └── serviceaccount-patch.yaml
    │
    ├── staging/                   # Staging environment
    │   ├── kustomization.yaml
    │   └── serviceaccount-patch.yaml
    │
    └── production/                # Production environment
        ├── kustomization.yaml
        └── serviceaccount-patch.yaml
```

## Base Configuration

The base directory contains the core Kubernetes resources that are shared across all environments.

### Base Resources

1. **Deployment** (`deployment.yaml`)
   - 3 replicas (default)
   - Resource requests: CPU 100m, Memory 128Mi
   - Resource limits: CPU 500m, Memory 512Mi
   - Security context with non-root user
   - Health probes (liveness and readiness)
   - Pod anti-affinity for multi-AZ distribution

2. **Service** (`service.yaml`)
   - ClusterIP type (default)
   - Port 80 → Target Port 8080

3. **ServiceAccount** (`serviceaccount.yaml`)
   - IRSA annotation placeholder

4. **HorizontalPodAutoscaler** (`hpa.yaml`)
   - Min replicas: 3
   - Max replicas: 10
   - Target CPU: 70%

### Base Kustomization

The `base/kustomization.yaml` defines:
- Resources to include
- Common labels
- Image name and tag parameters

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - serviceaccount.yaml
  - hpa.yaml

commonLabels:
  app: go-app

images:
  - name: go-app
    newName: <dockerhub-username>/go-app
    newTag: latest
```

## Overlay Customization

Overlays customize the base configuration for specific environments without modifying base files.

### Development Overlay

**Purpose**: Minimal resources for local/dev testing

**Customizations**:
- 1 replica (reduced from base 3)
- Image tag: `latest`
- Lower resource limits

**File**: `overlays/dev/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

images:
  - name: go-app
    newTag: latest

replicas:
  - name: go-app
    count: 1

patchesStrategicMerge:
  - serviceaccount-patch.yaml
```

### Staging Overlay

**Purpose**: Pre-production testing environment

**Customizations**:
- 2 replicas
- Semantic version tag (e.g., v1.0.0)
- Medium resource allocation

**File**: `overlays/staging/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

images:
  - name: go-app
    newTag: v1.0.0

replicas:
  - name: go-app
    count: 2

patchesStrategicMerge:
  - serviceaccount-patch.yaml
```

### Production Overlay

**Purpose**: Production workload with high availability

**Customizations**:
- 3 replicas (base default)
- Semantic version tag
- LoadBalancer service type
- Higher resource limits

**File**: `overlays/production/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

images:
  - name: go-app
    newTag: v1.0.0

patchesStrategicMerge:
  - serviceaccount-patch.yaml

patchesJson6902:
  - target:
      group: ""
      version: v1
      kind: Service
      name: go-app-service
    patch: |-
      - op: replace
        path: /spec/type
        value: LoadBalancer
```

## Common Customizations

### 1. Change Image Tag

Update the image tag in the overlay's `kustomization.yaml`:

```yaml
images:
  - name: go-app
    newTag: v2.0.0  # Change this value
```

### 2. Adjust Replica Count

Modify the replicas in the overlay:

```yaml
replicas:
  - name: go-app
    count: 5  # Change this value
```

### 3. Update Resource Limits

Create a patch file `resources-patch.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-app
spec:
  template:
    spec:
      containers:
        - name: go-app
          resources:
            requests:
              cpu: 200m
              memory: 256Mi
            limits:
              cpu: 1000m
              memory: 1Gi
```

Add to `kustomization.yaml`:
```yaml
patchesStrategicMerge:
  - resources-patch.yaml
```

### 4. Add Environment Variables

Create a patch file `env-patch.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-app
spec:
  template:
    spec:
      containers:
        - name: go-app
          env:
            - name: LOG_LEVEL
              value: "debug"
            - name: ENVIRONMENT
              value: "production"
```

Add to `kustomization.yaml`:
```yaml
patchesStrategicMerge:
  - env-patch.yaml
```

### 5. Change Service Type

Use JSON patch to change service type:

```yaml
patchesJson6902:
  - target:
      group: ""
      version: v1
      kind: Service
      name: go-app-service
    patch: |-
      - op: replace
        path: /spec/type
        value: LoadBalancer
```

### 6. Add ConfigMap

Create `configmap.yaml` in overlay:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  config.json: |
    {
      "feature_flags": {
        "new_feature": true
      }
    }
```

Add to `kustomization.yaml`:
```yaml
resources:
  - configmap.yaml
```

Mount in deployment patch:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-app
spec:
  template:
    spec:
      containers:
        - name: go-app
          volumeMounts:
            - name: config
              mountPath: /etc/config
      volumes:
        - name: config
          configMap:
            name: app-config
```

### 7. Update HPA Settings

Create `hpa-patch.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: go-app-hpa
spec:
  minReplicas: 5
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
```

Add to `kustomization.yaml`:
```yaml
patchesStrategicMerge:
  - hpa-patch.yaml
```

### 8. Add Ingress

Create `ingress.yaml` in overlay:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: go-app-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - app.example.com
      secretName: app-tls
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: go-app-service
                port:
                  number: 80
```

Add to `kustomization.yaml`:
```yaml
resources:
  - ingress.yaml
```

## Best Practices

### 1. Never Modify Base Files

Always create patches in overlays instead of modifying base files:

❌ **Bad**: Editing `base/deployment.yaml` directly
✅ **Good**: Creating `overlays/production/deployment-patch.yaml`

### 2. Use Strategic Merge for Simple Changes

For simple modifications, use strategic merge patches:

```yaml
patchesStrategicMerge:
  - replica-patch.yaml
  - resource-patch.yaml
```

### 3. Use JSON Patches for Precise Changes

For specific field updates, use JSON patches:

```yaml
patchesJson6902:
  - target:
      kind: Service
      name: go-app-service
    patch: |-
      - op: replace
        path: /spec/type
        value: LoadBalancer
```

### 4. Keep Overlays Minimal

Only include what's different from base:

```yaml
# Good - only differences
images:
  - name: go-app
    newTag: v2.0.0

# Bad - repeating base configuration
resources:
  - ../../base/deployment.yaml
  - ../../base/service.yaml
  # ... (use bases instead)
```

### 5. Use Descriptive Patch Names

Name patch files clearly:

- `resources-patch.yaml` - Resource limit changes
- `env-patch.yaml` - Environment variable additions
- `serviceaccount-patch.yaml` - ServiceAccount modifications

### 6. Document Custom Patches

Add comments to explain non-obvious patches:

```yaml
# Increase resources for production workload
# Based on load testing results from 2024-01-15
patchesStrategicMerge:
  - resources-patch.yaml
```

### 7. Version Control Everything

Commit all overlay changes to Git:

```bash
git add k8s/overlays/production/
git commit -m "Update production resources for increased load"
git push
```

## Validation

### Build and Validate

Test your customizations before applying:

```bash
# Build the overlay
kustomize build k8s/overlays/dev

# Validate the output
kustomize build k8s/overlays/dev | kubectl apply --dry-run=client -f -

# Check for errors
kustomize build k8s/overlays/dev | kubectl apply --dry-run=server -f -
```

### Compare Overlays

Compare different environments:

```bash
# Compare dev and production
diff <(kustomize build k8s/overlays/dev) <(kustomize build k8s/overlays/production)
```

### Verify Base Preservation

Ensure base files are unchanged:

```bash
# Check git status
cd k8s/base
git status

# Should show no modifications
```

## Examples

### Example 1: Add Monitoring Annotations

Create `overlays/production/monitoring-patch.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-app
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
```

Update `kustomization.yaml`:
```yaml
patchesStrategicMerge:
  - monitoring-patch.yaml
```

### Example 2: Add Node Affinity

Create `overlays/production/affinity-patch.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-app
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node.kubernetes.io/instance-type
                    operator: In
                    values:
                      - t3.medium
                      - t3.large
```

### Example 3: Add Secrets

Create `overlays/production/secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:
  database-url: "postgres://user:pass@host:5432/db"
```

Mount in deployment:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-app
spec:
  template:
    spec:
      containers:
        - name: go-app
          envFrom:
            - secretRef:
                name: app-secrets
```

## Troubleshooting

### Issue: Kustomize Build Fails

**Error**: `Error: accumulating resources: accumulation err='accumulating resources from '../../base': ...`

**Solution**: Check that base path is correct and base/kustomization.yaml exists

### Issue: Patch Not Applied

**Error**: Patch doesn't seem to take effect

**Solution**: 
- Verify patch file is listed in `patchesStrategicMerge` or `patchesJson6902`
- Check that resource names match exactly (case-sensitive)
- Use `kustomize build` to see the final output

### Issue: Duplicate Resources

**Error**: `may not add resource with an already registered id`

**Solution**: Don't list base resources in overlay's resources section, use `bases` instead

## Additional Resources

- [Kustomize Official Documentation](https://kustomize.io/)
- [Kubernetes Kustomize Tutorial](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- [Kustomize GitHub Repository](https://github.com/kubernetes-sigs/kustomize)
