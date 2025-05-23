# Simple Tailscale Integration (Sidecar Approach)

Much simpler alternative to the complex operator! This approach adds Tailscale as a sidecar container.

## 🚀 Quick Setup (5 minutes)

### 1. Get a Tailscale Auth Key
1. Go to https://login.tailscale.com/admin/settings/keys
2. Click **Generate auth key**
3. Settings:
   - **Reusable**: Yes
   - **Ephemeral**: Yes 
   - **Tags**: `tag:k8s`
4. Copy the key (starts with `tskey-auth-`)

### 2. Update the Secret
```bash
# Edit the simple approach file
nano kubernetes/infrastructure/tailscale/sidecar.yaml

# Replace: TS_AUTHKEY: "REPLACE_WITH_YOUR_TAILSCALE_AUTH_KEY"
# With your actual key: TS_AUTHKEY: "tskey-auth-k123456..."

# Encrypt with sops
sops -e -i kubernetes/infrastructure/tailscale/sidecar.yaml
```

### 3. Deploy
```bash
# Apply just this one file!
kubectl apply -f kubernetes/infrastructure/tailscale/sidecar.yaml

# Wait for pods
kubectl wait --for=condition=ready pod -l app=hello-app -n applications --timeout=120s
```

### 4. Test
```bash
# From any device on your tailnet:
curl http://hello-app-k3s
# Should return: Hello, World!
```

## ✅ Advantages of Simple Approach

- **Much less complexity** - Just one sidecar container
- **Easier debugging** - Standard kubectl logs
- **No cluster permissions** - Just normal pod permissions  
- **Quick setup** - 5 minutes vs 30+ minutes
- **Easy to understand** - Clear what each piece does

## ❌ Limitations

- **One service per deployment** - Need to modify each app individually
- **No automatic LoadBalancer** - Apps exposed directly via tailnet
- **Manual auth key management** - Need to rotate keys manually

## 🤔 When to Use Which?

**Use Simple Sidecar if:**
- You have 1-5 services to expose
- You want to understand what's happening
- You prefer simplicity over features
- You're just getting started

**Use Complex Operator if:**
- You have 10+ services to expose
- You want automatic LoadBalancer integration
- You need ingress controller features
- You're running a production cluster with many apps 