# NixOS-Managed Tailscale Integration

This directory contains a NixOS-managed Tailscale integration for your k3s cluster using SOPS for secret management. 

## 🎯 **RECOMMENDED: DaemonSet Approach**

**Use `daemonset.yaml` for cluster-wide Tailscale connectivity** - this is the recommended approach for most use cases where you want all cluster resources accessible via Tailscale.

### Why DaemonSet > Sidecar?

- ✅ **Resource Efficient**: 1 Tailscale per node vs 1 per pod
- ✅ **Operationally Simple**: Single auth key, easier troubleshooting  
- ✅ **Scalable**: Adding pods doesn't increase Tailscale overhead
- ✅ **Standard Practice**: How networking solutions typically work in K8s
- ✅ **Cluster-wide Access**: All pods/services accessible through subnet routes

## 🏗️ Architecture Overview

**DaemonSet Architecture:**
```
Tailnet ←→ [DaemonSet Tailscale] ←→ [Host Network] ←→ [Pod/Service Networks]
                    ↓
            Advertises cluster subnets:
            - Pod CIDR (10.42.0.0/16)  
            - Service CIDR (10.43.0.0/16)
```

This integration uses a **dual-secret architecture**:

- **`nixos-secrets.yaml`** - Raw SOPS file consumed by NixOS sops-nix for secret management
- **`secret.yaml`** - Kubernetes Secret manifest deployed to the cluster  
- **`daemonset.yaml`** - DaemonSet providing cluster-wide Tailscale connectivity

Everything is orchestrated through your `nix/modules/common/k3s-apps.nix` configuration.

## 🚀 Quick Start (DaemonSet)

### 1. Get a Tailscale Auth Key

1. Go to https://login.tailscale.com/admin/settings/keys
2. Click **Generate auth key**
3. Settings:
   - **Reusable**: Yes
   - **Ephemeral**: No (for persistent nodes)
   - **Tags**: `tag:k8s`
4. Copy the key (starts with `tskey-auth-`)

### 2. Update Secret Files

**Update NixOS secrets (for sops-nix):**
```bash
sops kubernetes/infrastructure/tailscale/nixos-secrets.yaml
# Update the TS_AUTHKEY value with your new key
```

**Update Kubernetes secrets:**
```bash
sops kubernetes/infrastructure/tailscale/secret.yaml
# Update the TS_AUTHKEY value in stringData section
```

### 3. Deploy DaemonSet

```bash
cd kubernetes/infrastructure/tailscale/
chmod +x deploy-daemonset.sh
./deploy-daemonset.sh
```

### 4. Enable Subnet Routes (Important!)

1. Go to https://login.tailscale.com/admin/machines
2. Find your k3s nodes (named like `k3s-core1`, `k3s-worker1`)
3. Click on each node → **Edit route settings**
4. **Enable the advertised routes**:
   - `10.42.0.0/16` (pods)
   - `10.43.0.0/16` (services)

### 5. Test Connectivity

```bash
# From your tailnet, test node connectivity
ping k3s-core1

# Test pod connectivity (get a pod IP first)
kubectl get pods -o wide
ping <pod-ip>

# Test service connectivity  
kubectl get svc
# Access services via their cluster IPs or create ingress
```

## 📁 File Breakdown

### `daemonset.yaml` ⭐ **RECOMMENDED**
Complete DaemonSet setup with:
- **RBAC**: Proper permissions for Tailscale
- **Persistent State**: Survives pod restarts
- **Subnet Advertisement**: Exposes pod/service networks
- **Resource Limits**: Efficient resource usage
- **Host Networking**: Direct access to node network

### `sidecar.yaml` (Legacy)
Individual pod sidecars - **NOT RECOMMENDED** for cluster-wide access:
- High resource overhead
- Complex configuration per pod
- Difficult to troubleshoot
- Doesn't scale well

### `nixos-secrets.yaml` & `secret.yaml`
Secret management (same as before):
```yaml
TS_AUTHKEY: ENC[AES256_GCM,data:...] 
```

## 🔧 Configuration Details

### DaemonSet Key Features

**Subnet Advertisement:**
```bash
--advertise-routes="${POD_CIDR},${SERVICE_CIDR}"
```
Makes all cluster resources accessible from your tailnet.

**Persistent State:**
```yaml
volumes:
  - name: tailscale-state
    hostPath:
      path: /var/lib/tailscale
```
Prevents re-registration on pod restart.

**Node Hostnames:**
Each node gets a unique hostname: `k3s-${NODE_NAME}`

### Accessing Individual Services

**Option 1: Direct IP Access**
```bash
# Get service cluster IP
kubectl get svc hello-app-service
# Access directly: http://10.43.xxx.xxx
```

**Option 2: Create Ingress**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-app-ingress
spec:
  rules:
    - host: hello-app.k3s.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello-app-service
                port:
                  number: 80
```

**Option 3: Tailscale Serve (Advanced)**
Run Tailscale serve on the node to expose specific services with custom hostnames.

## 🔄 Updating Auth Keys

```bash
# Update both secret files
sops kubernetes/infrastructure/tailscale/nixos-secrets.yaml
sops kubernetes/infrastructure/tailscale/secret.yaml

# Redeploy
./deploy-daemonset.sh

# Or just restart the DaemonSet
kubectl rollout restart daemonset/tailscale -n kube-system
```

## 🐛 Troubleshooting

### Check DaemonSet Status
```bash
kubectl get pods -n kube-system -l app=tailscale
kubectl logs -n kube-system -l app=tailscale
```

### Verify Subnet Routes
```bash
# From a DaemonSet pod
kubectl exec -n kube-system -l app=tailscale -- tailscale status
kubectl exec -n kube-system -l app=tailscale -- ip route
```

### Test Connectivity
```bash
# From your local machine (on tailnet)
ping k3s-core1
ping 10.42.0.1  # Pod network
ping 10.43.0.1  # Service network

# From inside cluster
kubectl run test-pod --image=nicolaka/netshoot -it --rm -- bash
# ping 100.x.x.x  # Your tailnet IP
```

### Common Issues

**Nodes not appearing in tailnet:**
- Check auth key validity
- Check pod logs for authentication errors
- Verify secret is properly deployed

**Can't reach pods/services from tailnet:**
- Enable subnet routes in Tailscale admin console
- Check CIDR ranges match your cluster
- Verify firewall rules on nodes

**DaemonSet pods crashing:**
- Check if privileged security context is allowed
- Verify host networking permissions
- Check node resource constraints

## 🏷️ Integration with NixOS

Update your `nix/modules/common/k3s-apps.nix` to deploy the DaemonSet instead of individual sidecars:

```nix
{
  # Deploy tailscale secrets and DaemonSet
  services.k3s.manifests = {
    tailscale-secret = pkgs.writeText "tailscale-secret.yaml" 
      (builtins.readFile ./kubernetes/infrastructure/tailscale/secret.yaml);
    tailscale-daemonset = pkgs.writeText "tailscale-daemonset.yaml"
      (builtins.readFile ./kubernetes/infrastructure/tailscale/daemonset.yaml);
  };
}
```

## 🔐 Security Notes

- DaemonSet requires privileged access for network configuration
- Host networking provides direct node access  
- Subnet routes expose internal cluster networks
- Use proper Tailscale ACLs to control access
- Consider using tags for fine-grained permissions

---

**Migration from Sidecar:** Simply deploy the DaemonSet and remove sidecar configurations. The DaemonSet provides superior cluster-wide connectivity with much better resource efficiency. 