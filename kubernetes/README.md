# Kubernetes Resources

This directory contains all Kubernetes manifests for the cluster.

## Directory Structure

- **apps/**: Application deployments (e.g., hello-app)
- **infrastructure/**: Cluster infrastructure components (e.g., tailscale)
- **kustomize/**: Kustomize overlays for different environments
- **namespaces/**: Namespace definitions

## Usage

You can apply resources directly or use Kustomize:

```bash
# Apply all resources using Kustomize
kubectl apply -k kustomize/base

# Apply a specific resource
kubectl apply -f apps/hello-app/deployment.yaml
``` 