# Kubernetes Applications

This directory contains Kubernetes manifests that are **automatically deployed** by NixOS during `nixos-rebuild switch` operations.

## 🚀 Auto-Deployment Architecture

Applications are deployed using the built-in K3s manifest deployment feature via NixOS configuration:

- **Manifests**: Defined in `nix/modules/common/k3s-apps.nix` as pure Nix code
- **Secrets**: Handled by sops-nix templates, automatically decrypted and placed in `/var/lib/rancher/k3s/server/manifests/`
- **Deployment**: Happens automatically on every `nixos-rebuild switch` on the server node

## 📁 Directory Structure

```
kubernetes/
├── apps/                    # Legacy YAML files (for reference)
├── infrastructure/         # Infrastructure configurations
│   └── tailscale/          # Tailscale sidecar configs (encrypted)
└── kustomize/              # Legacy kustomize configs (now empty)
```

## 🔄 Workflow

1. **Make changes** to `nix/modules/common/k3s-apps.nix`
2. **Commit and push** to git
3. **Pull on server node**: `git pull`
4. **Rebuild**: `nixos-rebuild switch --flake .#core1`
5. **Done!** Applications are automatically deployed

## 🔐 Adding Secrets

For applications that need secrets:

1. **Add secret to sops file**: `sops kubernetes/infrastructure/tailscale/sidecar.yaml`
2. **Reference in NixOS module**: Use `config.sops.secrets."secret-name"`
3. **Create template**: Use `sops.templates` to place in K3s manifests directory

## ✅ Benefits

- **Declarative**: Everything in version control
- **Automatic**: No manual kubectl commands
- **Secure**: Secrets properly handled with sops-nix
- **Simple**: One command to deploy everything
- **Atomic**: All changes applied together

## 🏃 Current Applications

- **hello-app**: Example app with Tailscale sidecar for secure access
- **Namespaces**: Applications namespace auto-created 