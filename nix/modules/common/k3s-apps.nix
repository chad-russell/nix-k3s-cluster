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
    # Namespaces
    namespaces = {
      content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = {
          name = appConfig.namespace;
        };
      };
    };

    # Hello-app deployment (using your custom image)
    hello-app = {
      content = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "hello-app";
          namespace = appConfig.namespace;
          labels = {
            app = "hello-app";
          };
        };
        spec = {
          replicas = appConfig.helloApp.replicas;
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
                image = appConfig.helloApp.image;
                ports = [{ 
                  containerPort = appConfig.helloApp.containerPort; 
                }];
                env = [{ 
                  name = "PORT"; 
                  value = toString appConfig.helloApp.containerPort; 
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
          name = "hello-app-service";
          namespace = appConfig.namespace;
          annotations = {
            "tailscale.com/hostname" = appConfig.helloApp.tailscaleHostname;
          };
        };
        spec = {
          selector = {
            app = "hello-app";
          };
          ports = [{
            protocol = "TCP";
            port = appConfig.helloApp.servicePort;
            targetPort = appConfig.helloApp.containerPort;
          }];
          type = "LoadBalancer";
          loadBalancerClass = "tailscale";
        };
      };
    };
  };
}