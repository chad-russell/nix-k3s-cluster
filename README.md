# NixOS K3s Cluster

A fully declarative NixOS-managed Kubernetes (K3s) cluster with automatic application deployment and secure Tailscale integration.

## Features

- 🚀 **Fully Declarative**: Everything managed through NixOS configurations - no manual kubectl needed
- 🔐 **Integrated Secrets Management**: Uses sops-nix for encrypted secrets
- 🌐 **Simple Tailscale Integration**: Secure access via lightweight sidecar containers
- 🎯 **GitOps Workflow**: `git pull` + `nixos-rebuild switch` = fully deployed cluster
- 📦 **Auto-deployed Applications**: Kubernetes apps deploy automatically during system rebuild

## Project Structure

```
.
├── flake.nix            # Main NixOS flake configuration
├── flake.lock           # Lock file for flake dependencies
├── nix/                 # NixOS configurations
│   ├── modules/         # NixOS modules
│   │   ├── common/      # Shared configurations
│   │   │   ├── k3s-node.nix  # K3s node setup
│   │   │   └── k3s-apps.nix  # Auto-deployed Kubernetes apps
│   │   └── hosts/       # Host-specific configurations
│   └── profiles/        # Reusable profiles for different node types
├── kubernetes/          # Kubernetes manifests (reference/legacy)
│   ├── apps/            # Application deployments
│   └── kustomize/       # Legacy kustomize configs
├── secrets/             # Encrypted secrets (managed by sops-nix)
└── docs/                # Documentation
    └── DEPLOY_GUIDE.md  # Deployment instructions
```

## Quick Start

### 1. Deploy the Cluster
See [Deployment Guide](docs/DEPLOY_GUIDE.md) for detailed instructions on how to deploy the K3s cluster.

### 2. Applications Deploy Automatically! 
After your cluster is running, applications are automatically deployed on every `nixos-rebuild switch`:

```bash
# Pull latest changes
git pull

# Rebuild system - apps deploy automatically!
nixos-rebuild switch --flake .#core1
```

That's it! No kubectl commands needed.

### 3. Access Your Applications
Once deployed, you can access the hello-app from any device on your Tailscale network:
```bash
curl http://hello-app-k3s
```

## How It Works

- **Applications** are defined in `nix/modules/common/k3s-apps.nix` as pure Nix code
- **Secrets** are handled by sops-nix templates, automatically decrypted during rebuild
- **K3s** automatically applies manifests from `/var/lib/rancher/k3s/server/manifests/`
- **Everything** happens declaratively during `nixos-rebuild switch`

## Prerequisites

- Nix with flakes enabled
- SOPS and Age for secret management
- NixOS machines for running the K3s cluster
- Network connectivity between nodes
- Tailscale account (for secure remote access)

## Security Features

- **Zero-Trust Networking**: Applications are only accessible via your private Tailscale network
- **Encrypted Secrets**: All sensitive data is encrypted with sops-nix before being committed
- **Declarative Security**: All security configurations are version-controlled
- **Automatic Secret Rotation**: Secrets are re-applied on every system rebuild 