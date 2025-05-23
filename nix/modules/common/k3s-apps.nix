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
    # Namespace
    namespaces = {
      content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = {
          name = "applications";
        };
      };
    };

    # Test with a service instead of deployment
    test-service = {
      content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "test-service";
          namespace = "applications";
        };
        spec = {
          selector = {
            app = "test-app";
          };
          ports = [{
            protocol = "TCP";
            port = 80;
            targetPort = 8080;
          }];
        };
      };
    };
  };
}