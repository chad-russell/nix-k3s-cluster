# Kubernetes Structure Recommendations

This document outlines potential improvements to the Kubernetes directory structure for scaling the homelab in the future.

## Recommended Structure Enhancements

Below are recommendations for enhancing the Kubernetes structure as the cluster grows to support multiple nodes and more applications:

1. **Environment-specific Kustomize Overlays**
   - `kubernetes/kustomize/environments/local/`
   - `kubernetes/kustomize/environments/cloud/`
   - Allows for environment-specific configurations without duplicating base manifests

2. **Improved Namespace Organization**
   - Organize resources by namespace in dedicated directories:
   - `kubernetes/namespaces/applications/`
   - `kubernetes/namespaces/infrastructure/` 
   - `kubernetes/namespaces/monitoring/`

3. **Enhanced Infrastructure Organization**
   - `kubernetes/infrastructure/core/` - For critical components
   - `kubernetes/infrastructure/networking/` - For Tailscale, Ingress controllers
   - `kubernetes/infrastructure/storage/` - For storage classes, persistent volumes

4. **Application Grouping**
   - Group related applications in subdirectories:
   - `kubernetes/apps/media/`
   - `kubernetes/apps/home-automation/`
   - `kubernetes/apps/monitoring/`

5. **Configuration Management**
   - Add a dedicated directory for ConfigMaps and Secrets:
   - `kubernetes/configs/`

6. **Helm Releases Structure**
   - If using Helm charts via Flux CD or ArgoCD:
   - `kubernetes/helm-releases/`

7. **Node Affinity and Tainting**
   - For mixed environment (local + cloud nodes):
   - Add node label configurations
   - Templates with node affinity rules

8. **Common Resource Templates**
   - `kubernetes/templates/` - For reusable manifest templates

9. **RBAC Definitions**
   - `kubernetes/rbac/` - For role-based access control

10. **GitOps Structure**
    - Directory structure for Flux or ArgoCD GitOps workflows

## Priority for Initial Setup

For your current single-app deployment with local nodes only, consider implementing:

1. **Environment Overlays** - Start with local environment overlay
2. **Infrastructure Organization** - Organize core infrastructure components
3. **Namespace Organization** - Group resources by namespace

The rest can be added as your homelab grows in complexity. 