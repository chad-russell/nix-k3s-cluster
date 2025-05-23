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
in
{
  # Configure sops for any application secrets that might be needed
  # (Note: Tailscale auth key no longer needed since using host Tailscale)

  # Auto-deploy Kubernetes manifests using the built-in K3s feature
  services.k3s.manifests = lib.mkIf isServer {
    # Just the namespace for now - to test if basic functionality works
    namespaces = {
      content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = {
          name = "applications";
        };
      };
    };
  };
}