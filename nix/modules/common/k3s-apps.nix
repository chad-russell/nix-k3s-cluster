# k3s-apps.nix: Auto-deployment of Kubernetes applications
{ config, pkgs, lib, role, flakeRoot, ... }:

let
  # Only deploy apps on the server node
  isServer = role == "server";
  
  # =============================================================================
  # Application Configuration Variables
  # =============================================================================
  appConfig = {
    # Hello App Configuration
    helloApp = {
      image = "chadrussell/hello-app:latest";  # Your custom image
      replicas = 2;
      containerPort = 8080;
      servicePort = 80;
      # Tailscale LoadBalancer configuration
      tailscaleHostname = "hello-app-k3s";
    };
    
    # Default namespace for applications
    namespace = "applications";
  };

  # Create manifest files
  namespaceManifest = pkgs.writeText "namespace.yaml" ''
    apiVersion: v1
    kind: Namespace
    metadata:
      name: ${appConfig.namespace}
  '';

  deploymentManifest = pkgs.writeText "hello-app-deployment.yaml" ''
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: hello-app
      namespace: ${appConfig.namespace}
      labels:
        app: hello-app
    spec:
      replicas: ${toString appConfig.helloApp.replicas}
      selector:
        matchLabels:
          app: hello-app
      template:
        metadata:
          labels:
            app: hello-app
        spec:
          containers:
          - name: hello-app
            image: ${appConfig.helloApp.image}
            ports:
            - containerPort: ${toString appConfig.helloApp.containerPort}
            env:
            - name: PORT
              value: "${toString appConfig.helloApp.containerPort}"
  '';

  serviceManifest = pkgs.writeText "hello-app-service.yaml" ''
    apiVersion: v1
    kind: Service
    metadata:
      name: hello-app-service
      namespace: ${appConfig.namespace}
      annotations:
        tailscale.com/hostname: ${appConfig.helloApp.tailscaleHostname}
    spec:
      selector:
        app: hello-app
      ports:
      - protocol: TCP
        port: ${toString appConfig.helloApp.servicePort}
        targetPort: ${toString appConfig.helloApp.containerPort}
      type: LoadBalancer
      loadBalancerClass: tailscale
  '';

in
{
  # Configure sops for any application secrets that might be needed
  # (Note: Tailscale auth key no longer needed since using host Tailscale)

  # Create a systemd service to deploy manifests using kubectl
  systemd.services.deploy-k3s-apps = lib.mkIf isServer {
    description = "Deploy K3s Applications";
    after = [ "k3s.service" ];
    wants = [ "k3s.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "deploy-k3s-apps" ''
        # Wait for k3s to be ready
        until ${pkgs.k3s}/bin/kubectl get nodes > /dev/null 2>&1; do
          echo "Waiting for k3s to be ready..."
          sleep 5
        done
        
        # Apply manifests
        ${pkgs.k3s}/bin/kubectl apply -f ${namespaceManifest}
        ${pkgs.k3s}/bin/kubectl apply -f ${deploymentManifest}
        ${pkgs.k3s}/bin/kubectl apply -f ${serviceManifest}
        
        echo "K3s applications deployed successfully"
      '';
      
      ExecStop = pkgs.writeShellScript "undeploy-k3s-apps" ''
        ${pkgs.k3s}/bin/kubectl delete -f ${serviceManifest} || true
        ${pkgs.k3s}/bin/kubectl delete -f ${deploymentManifest} || true
        # Keep namespace for now
      '';
    };
    
    environment = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };
  };
}