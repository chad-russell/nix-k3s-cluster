# NixOS K3s Cluster

A NixOS-managed Kubernetes (K3s) cluster with declarative configuration.

## Project Structure

```
.
├── flake.nix            # Main NixOS flake configuration
├── flake.lock           # Lock file for flake dependencies
├── kubernetes/          # All Kubernetes manifests
│   ├── apps/            # Application deployments
│   │   ├── hello-app/   # Example application
│   │   └── ...
│   ├── infrastructure/  # Cluster infrastructure components
│   │   ├── tailscale/
│   │   └── ...
│   ├── kustomize/       # Kustomize overlays (if using)
│   └── namespaces/      # Namespace definitions
├── nix/                 # Nix configurations
│   ├── modules/         # NixOS modules
│   │   ├── common/      # Shared configurations
│   │   └── hosts/       # Host-specific configurations
│   ├── profiles/        # Reusable profiles for different node types
│   └── pkgs/            # Custom packages
├── secrets/             # Encrypted secrets (managed by sops-nix)
└── docs/                # Documentation
    └── DEPLOY_GUIDE.md  # Deployment instructions
```

## Getting Started

See [Deployment Guide](docs/DEPLOY_GUIDE.md) for detailed instructions on how to deploy the cluster.

## Prerequisites

- Nix with flakes enabled
- SOPS and Age for secret management
- NixOS machines for running the K3s cluster
- Network connectivity between nodes 