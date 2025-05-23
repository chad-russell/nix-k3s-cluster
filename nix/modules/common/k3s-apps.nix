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
    # Create applications namespace
    applications-namespace.content = {
      apiVersion = "v1";
      kind = "Namespace";
      metadata = {
        name = "applications";
      };
    };

    # Hello app deployment
    hello-app-deployment.content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "hello-app";
        namespace = "applications";
        labels = {
          app = "hello-app";
        };
      };
      spec = {
        replicas = 2;
        selector = {
          matchLabels = {
            app = "hello-app";
          };
        };
        template = {
          metadata = {
            labels = {
              app = "hello-app";
            };
          };
          spec = {
            containers = [{
              name = "hello-app";
              image = "chadrussell/hello-app:latest";
              ports = [{
                containerPort = 8080;
              }];
            }];
          };
        };
      };
    };

    # Hello app service with Tailscale LoadBalancer
    hello-app-service.content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "hello-app-service";
        namespace = "applications";
        annotations = {
          "tailscale.com/hostname" = "hello-app-k3s";
        };
      };
      spec = {
        selector = {
          app = "hello-app";
        };
        ports = [{
          protocol = "TCP";
          port = 80;
          targetPort = 8080;
        }];
        type = "LoadBalancer";
        loadBalancerClass = "tailscale";
      };
    };
  };
} 