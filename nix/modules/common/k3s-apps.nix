# k3s-apps.nix: Auto-deployment of Kubernetes applications
{ config, pkgs, lib, role, flakeRoot, ... }:

let
  # Only deploy apps on the server node
  isServer = role == "server";
in
{
  # Configure sops for any application secrets that might be needed
  # (Note: Tailscale auth key no longer needed since using host Tailscale)

  # Auto-deploy Kubernetes manifests using the built-in K3s feature
  services.k3s.manifests = lib.mkIf isServer {
    # Namespaces
    namespaces = {
      content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata.name = "applications";
      };
    };

    # Example hello-app (using host Tailscale connectivity)
    hello-app = {
      content = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "hello-app";
          namespace = "applications";
        };
        spec = {
          replicas = 2;
          selector.matchLabels.app = "hello-app";
          template = {
            metadata.labels.app = "hello-app";
            spec = {
              containers = [{
                name = "hello-app";
                image = "gcr.io/google-samples/hello-app:1.0";
                ports = [{ containerPort = 8080; }];
                env = [{ name = "PORT"; value = "8080"; }];
              }];
            };
          };
        };
      };
    };

    # Hello app service
    hello-app-service = {
      content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "hello-app-service";
          namespace = "applications";
        };
        spec = {
          selector.app = "hello-app";
          ports = [{
            protocol = "TCP";
            port = 80;
            targetPort = 8080;
          }];
          type = "ClusterIP";
        };
      };
    };
  };
} 