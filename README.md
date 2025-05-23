# NixOS K3s Cluster

A NixOS-managed Kubernetes (K3s) cluster with declarative configuration and simple Tailscale integration for secure remote access.

## Features

- 🚀 **Declarative K3s Setup**: Fully managed through NixOS configurations
- 🔐 **Integrated Secrets Management**: Uses sops-nix for encrypted secrets
- 🌐 **Simple Tailscale Integration**: Secure access via lightweight sidecar containers
- 🎯 **GitOps Ready**: All configurations are version-controlled and declarative
- 📦 **Example Applications**: Includes hello-app with Tailscale exposure

## Project Structure

```
.
├── flake.nix            # Main NixOS flake configuration
├── flake.lock           # Lock file for flake dependencies
├── kubernetes/          # All Kubernetes manifests
│   ├── apps/            # Application deployments
│   ├── infrastructure/  # Cluster infrastructure components
│   │   ├── tailscale/   # Simple Tailscale sidecar integration
│   │   └── ...
│   ├── kustomize/       # Kustomize overlays
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

## Quick Start

### 1. Deploy the Cluster
See [Deployment Guide](docs/DEPLOY_GUIDE.md) for detailed instructions on how to deploy the K3s cluster.

### 2. Set Up Tailscale Integration (5 minutes!)
Follow the instructions in [kubernetes/infrastructure/tailscale/README.md](kubernetes/infrastructure/tailscale/README.md) to:
- Get a Tailscale auth key
- Deploy applications with Tailscale sidecar containers
- Access apps securely through your tailnet

### 3. Access Your Applications
Once configured, you can access the hello-app from any device on your Tailscale network:
```bash
curl http://hello-app-k3s
```

## Prerequisites

- Nix with flakes enabled
- SOPS and Age for secret management
- NixOS machines for running the K3s cluster
- Network connectivity between nodes
- Tailscale account (for secure remote access)

## Security Features

- **Zero-Trust Networking**: Applications are only accessible via your private Tailscale network
- **Encrypted Secrets**: All sensitive data is encrypted with sops-nix before being committed
- **Simple & Secure**: Lightweight sidecar approach that's easy to understand and debug
- **Declarative Security**: All security configurations are version-controlled 