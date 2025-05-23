# k3s-apps.nix: Auto-deployment of Kubernetes applications
{ config, pkgs, lib, role, flakeRoot, ... }:

let
  # Only deploy apps on the server node
  isServer = role == "server";

  # Application configuration variables - centralized for easy maintenance
  apps = {
    hello-app = {
      name = "hello-app";
      namespace = "applications";
      image = "chadrussell/hello-app:latest";
      replicas = 2;
      containerPort = 8080;
      servicePort = 80;
      tailscale = {
        hostname = "hello-app-k3s";
        loadBalancerClass = "tailscale";
      };
    };
  };

  # Generate YAML manifests as strings
  namespaceYaml = ''
    apiVersion: v1
    kind: Namespace
    metadata:
      name: ${apps.hello-app.namespace}
  '';

  deploymentYaml = ''
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ${apps.hello-app.name}
      namespace: ${apps.hello-app.namespace}
      labels:
        app: ${apps.hello-app.name}
    spec:
      replicas: ${toString apps.hello-app.replicas}
      selector:
        matchLabels:
          app: ${apps.hello-app.name}
      template:
        metadata:
          labels:
            app: ${apps.hello-app.name}
        spec:
          containers:
          - name: ${apps.hello-app.name}
            image: ${apps.hello-app.image}
            ports:
            - containerPort: ${toString apps.hello-app.containerPort}
  '';

  serviceYaml = ''
    apiVersion: v1
    kind: Service
    metadata:
      name: ${apps.hello-app.name}-service
      namespace: ${apps.hello-app.namespace}
      annotations:
        tailscale.com/hostname: ${apps.hello-app.tailscale.hostname}
    spec:
      selector:
        app: ${apps.hello-app.name}
      ports:
      - protocol: TCP
        port: ${toString apps.hello-app.servicePort}
        targetPort: ${toString apps.hello-app.containerPort}
      type: LoadBalancer
      loadBalancerClass: ${apps.hello-app.tailscale.loadBalancerClass}
  '';

  # Create deployment script
  deployScript = pkgs.writeShellScript "deploy-k8s-apps" ''
    set -euo pipefail
    
    # Wait for k3s to be ready
    echo "Waiting for k3s to be ready..."
    until ${pkgs.k3s}/bin/k3s kubectl get nodes >/dev/null 2>&1; do
      echo "Waiting for k3s to start..."
      sleep 5
    done
    
    echo "Deploying applications namespace..."
    echo '${namespaceYaml}' | ${pkgs.k3s}/bin/k3s kubectl apply -f -
    
    echo "Deploying hello-app..."
    echo '${deploymentYaml}' | ${pkgs.k3s}/bin/k3s kubectl apply -f -
    echo '${serviceYaml}' | ${pkgs.k3s}/bin/k3s kubectl apply -f -
    
    echo "Applications deployed successfully!"
  '';
in
{
  # Deploy apps using a systemd service instead of k3s manifests
  systemd.services.k3s-deploy-apps = lib.mkIf isServer {
    description = "Deploy K3s Applications";
    wantedBy = [ "multi-user.target" ];
    after = [ "k3s.service" ];
    requires = [ "k3s.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = deployScript;
      User = "root";
    };
  };
} 