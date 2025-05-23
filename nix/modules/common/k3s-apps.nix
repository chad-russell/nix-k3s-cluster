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
  
  # Namespace configuration
  namespaces = {
    applications = "applications";
  };
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
        metadata.name = namespaces.applications;
      };
    };

    # Hello app deployment
    hello-app-deployment = {
      content = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = apps.hello-app.name;
          namespace = apps.hello-app.namespace;
          labels = {
            app = apps.hello-app.name;
          };
        };
        spec = {
          replicas = apps.hello-app.replicas;
          selector = {
            matchLabels = {
              app = apps.hello-app.name;
            };
          };
          template = {
            metadata = {
              labels = {
                app = apps.hello-app.name;
              };
            };
            spec = {
              containers = [{
                name = apps.hello-app.name;
                image = apps.hello-app.image;
                ports = [{
                  containerPort = apps.hello-app.containerPort;
                }];
              }];
            };
          };
        };
      };
    };

    # Hello app service with Tailscale LoadBalancer
    hello-app-service = {
      content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "${apps.hello-app.name}-service";
          namespace = apps.hello-app.namespace;
          annotations = {
            "tailscale.com/hostname" = apps.hello-app.tailscale.hostname;
          };
        };
        spec = {
          selector = {
            app = apps.hello-app.name;
          };
          ports = [{
            protocol = "TCP";
            port = apps.hello-app.servicePort;
            targetPort = apps.hello-app.containerPort;
          }];
          type = "LoadBalancer";
          loadBalancerClass = apps.hello-app.tailscale.loadBalancerClass;
        };
      };
    };
  };
} 