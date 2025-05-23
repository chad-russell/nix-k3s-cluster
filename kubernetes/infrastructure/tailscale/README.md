# NixOS-Managed Tailscale Integration

This directory contains a NixOS-managed Tailscale integration for your k3s cluster using SOPS for secret management. The setup provides automatic deployment of applications with Tailscale sidecars through your NixOS configuration.

## 🏗️ Architecture Overview

This integration uses a **dual-secret architecture**:

- **`nixos-secrets.yaml`** - Raw SOPS file consumed by NixOS sops-nix for secret management
- **`secret.yaml`** - Kubernetes Secret manifest deployed to the cluster  
- **`sidecar.yaml`** - Clean application manifests (Deployment + Service) that reference the secrets

Everything is orchestrated through your `nix/modules/common/k3s-apps.nix` configuration, providing:
- ✅ Automated secret deployment and rotation
- ✅ Zero-touch application deployment via `nixos-rebuild`
- ✅ Proper SOPS encryption with age keys
- ✅ Clean separation of concerns

## 🚀 Quick Start

### 1. Get a Tailscale Auth Key

1. Go to https://login.tailscale.com/admin/settings/keys
2. Click **Generate auth key**
3. Settings:
   - **Reusable**: Yes
   - **Ephemeral**: Yes 
   - **Tags**: `tag:k8s`
4. Copy the key (starts with `tskey-auth-`)

### 2. Update Both Secret Files

**Update NixOS secrets (for sops-nix):**
```bash
# Decrypt, edit, and re-encrypt
sops kubernetes/infrastructure/tailscale/nixos-secrets.yaml

# Update the TS_AUTHKEY value with your new key
# Save and exit - SOPS will re-encrypt automatically
```

**Update Kubernetes secrets:**
```bash
# Decrypt, edit, and re-encrypt  
sops kubernetes/infrastructure/tailscale/secret.yaml

# Update the TS_AUTHKEY value in stringData section
# Save and exit - SOPS will re-encrypt automatically
```

### 3. Deploy via NixOS

```bash
# Deploy to your cluster nodes (example for core1)
nixos-rebuild switch --flake .#core1

# Or deploy to all nodes
nix run .#deploy
```

### 4. Verify Deployment

```bash
# Check if secrets are properly installed
sudo ls -la /run/secrets/

# Check if pods are running
kubectl get pods -n applications -l app=hello-app

# Check pod logs
kubectl logs -n applications -l app=hello-app -c tailscale

# Test connectivity from your tailnet
curl http://hello-app-k3s
```

## 📁 File Breakdown

### `nixos-secrets.yaml`
Raw SOPS-encrypted file for NixOS consumption:
```yaml
TS_AUTHKEY: ENC[AES256_GCM,data:...] 
sops:
  age: [...]
```
- Used by sops-nix to create `/run/secrets/TS_AUTHKEY`
- Consumed by `k3s-apps.nix` for secret template generation

### `secret.yaml` 
Kubernetes Secret manifest:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tailscale-auth
  namespace: applications
stringData:
  TS_AUTHKEY: ENC[AES256_GCM,data:...]
```
- Deployed as a Kubernetes secret via `k3s-apps.nix`
- Referenced by pods via `secretKeyRef`

### `sidecar.yaml`
Clean application manifests:
- **Deployment**: hello-app with Tailscale sidecar container
- **Service**: ClusterIP service for internal communication
- **No hardcoded secrets** - uses `secretKeyRef` to reference Kubernetes secrets

## 🔧 Configuration Details

### Tailscale Sidecar Configuration

The sidecar container uses these key environment variables:

```yaml
env:
  - name: TS_AUTHKEY
    valueFrom:
      secretKeyRef:
        name: tailscale-auth
        key: TS_AUTHKEY
  - name: TS_HOSTNAME
    value: hello-app-k3s
  - name: TS_SERVE_CONFIG
    value: |
      {
        "TCP": { "443": {"HTTPS": true}, "80": {"HTTP": true} },
        "Web": {
          "hello-app-k3s:443": {
            "Handlers": {"/": {"Proxy": "http://127.0.0.1:8080"}}
          }
        }
      }
```

### SOPS Configuration

Your `.sops.yaml` handles encryption rules:
```yaml
creation_rules:
  - path_regex: kubernetes/infrastructure/tailscale/nixos-secrets\.yaml$
    age: >-
      age12lhj5rwp25uxpp5dkaa6z998m7mmwcg7dequc46a68x46zdza4sqa7uezf,
      age1262ecjgugtm72dcdzxzk5gdeays4rxnedqrv280lvkfpwz5q5pnqdgc3ar,
      [... other age keys ...]
  - path_regex: kubernetes/infrastructure/tailscale/secret\.yaml$
    age: [same keys]
    encrypted_regex: ^(data|stringData)$
```

## 🔄 Updating Auth Keys

When you need to rotate Tailscale auth keys:

1. **Generate new key** from Tailscale admin console
2. **Update both secret files** using `sops` command 
3. **Deploy changes** via `nixos-rebuild switch --flake .#core1`
4. **Verify deployment** - pods will automatically restart with new secrets

## 🐛 Troubleshooting

### Check Secret Deployment
```bash
# Verify NixOS secrets are available
sudo cat /run/secrets/TS_AUTHKEY

# Verify Kubernetes secrets exist
kubectl get secret tailscale-auth -n applications -o yaml
```

### Check Pod Status
```bash
# Check pod events
kubectl describe pod -n applications -l app=hello-app

# Check tailscale container logs
kubectl logs -n applications -l app=hello-app -c tailscale

# Check hello-app container logs  
kubectl logs -n applications -l app=hello-app -c hello-app
```

### Common Issues

**SOPS MAC mismatch errors:**
- Don't manually copy/paste encrypted values between files
- Always use `sops -e -i filename.yaml` to encrypt
- Ensure `.sops.yaml` rules match your file paths

**Pod CrashLoopBackOff:**
- Check if auth key is valid and not expired
- Verify secret exists: `kubectl get secret tailscale-auth -n applications`
- Check container capabilities: Tailscale needs `NET_ADMIN`

**Can't reach service from tailnet:**
- Verify hostname in Tailscale admin console
- Check if `TS_SERVE_CONFIG` is correct
- Test internal connectivity: `kubectl exec -it <pod> -- curl localhost:8080`

## 🏷️ Integration with NixOS

This setup integrates with your broader NixOS configuration through:

- **`nix/modules/common/k3s-apps.nix`** - Orchestrates secret management and deployment
- **SOPS age keys** - Shared across your entire cluster for consistent encryption
- **Automatic deployment** - Changes deploy when you rebuild any cluster node
- **Centralized management** - All infrastructure as code in your flake

## 🔐 Security Notes

- Auth keys are encrypted at rest using SOPS with age encryption
- Keys are only decrypted in memory during deployment
- Ephemeral keys provide automatic cleanup when pods are destroyed
- No secrets stored in git history (only encrypted values)

---

**Next Steps:** To add Tailscale to additional applications, copy the sidecar pattern from `sidecar.yaml` and update the `TS_HOSTNAME` and service configuration accordingly. 