# k3s-apps.nix: Auto-deployment of Kubernetes applications
{ config, pkgs, lib, role, flakeRoot, ... }:

let
  # Only deploy apps on the server node
  isServer = role == "server";
in
{
  # Configure sops for the Tailscale auth key
  sops.secrets."tailscale-auth-key" = lib.mkIf isServer {
    sopsFile = "${flakeRoot}/kubernetes/infrastructure/tailscale/nixos-secrets.yaml";
    key = "TS_AUTHKEY";
  };

  # Explicitly disable the old template to prevent broken symlinks
  sops.templates."tailscale-secret" = lib.mkIf isServer {
    content = "";
    path = "/dev/null";  # This effectively disables the old template
  };

  # Create the secret manifest using sops templates for kube-system namespace
  sops.templates."tailscale-secret-kube-system" = lib.mkIf isServer {
    content = builtins.toJSON {
      apiVersion = "v1";
      kind = "Secret";
      metadata = {
        name = "tailscale-auth";
        namespace = "kube-system";
      };
      type = "Opaque";
      stringData = {
        TS_AUTHKEY = config.sops.placeholder."tailscale-auth-key";
      };
    };
    path = "/var/lib/rancher/k3s/server/manifests/tailscale-secret-kube-system.json";
  };

  # Also create secret for applications namespace (for any remaining sidecar apps)
  sops.templates."tailscale-secret-applications" = lib.mkIf isServer {
    content = builtins.toJSON {
      apiVersion = "v1";
      kind = "Secret";
      metadata = {
        name = "tailscale-auth";
        namespace = "applications";
      };
      type = "Opaque";
      stringData = {
        TS_AUTHKEY = config.sops.placeholder."tailscale-auth-key";
      };
    };
    path = "/var/lib/rancher/k3s/server/manifests/tailscale-secret-applications.json";
  };

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

    # Tailscale DaemonSet ServiceAccount
    tailscale-daemonset-serviceaccount = {
      content = {
        apiVersion = "v1";
        kind = "ServiceAccount";
        metadata = {
          name = "tailscale-daemonset";
          namespace = "kube-system";
        };
      };
    };

    # Tailscale DaemonSet ClusterRole
    tailscale-daemonset-clusterrole = {
      content = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRole";
        metadata = {
          name = "tailscale-daemonset";
        };
        rules = [
          {
            apiGroups = [ "" ];
            resources = [ "nodes" ];
            verbs = [ "get" "list" ];
          }
          {
            apiGroups = [ "" ];
            resources = [ "secrets" ];
            verbs = [ "create" "get" "update" "patch" ];
          }
        ];
      };
    };

    # Tailscale DaemonSet ClusterRoleBinding
    tailscale-daemonset-clusterrolebinding = {
      content = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRoleBinding";
        metadata = {
          name = "tailscale-daemonset";
        };
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "ClusterRole";
          name = "tailscale-daemonset";
        };
        subjects = [{
          kind = "ServiceAccount";
          name = "tailscale-daemonset";
          namespace = "kube-system";
        }];
      };
    };

    # Tailscale entrypoint ConfigMap
    tailscale-entrypoint = {
      content = {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "tailscale-entrypoint";
          namespace = "kube-system";
        };
        data = {
          "entrypoint.sh" = ''
            #!/bin/sh
            set -e

            # Get node name for hostname
            NODE_NAME=$(cat /etc/hostname)

            # Start tailscaled with persistent state
            mkdir -p /var/lib/tailscale
            tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &

            # Wait for tailscaled to be ready
            until tailscale status 2>&1 | grep -q 'Logged out\|Logged in'; do
              echo "Waiting for tailscaled to start..."
              sleep 2
            done

            # Bring up tailscale with routes
            echo "Bringing up Tailscale on node: $NODE_NAME"
            tailscale up \
              --authkey="''${TS_AUTHKEY}" \
              --hostname="k3s-''${NODE_NAME}" \
              --accept-routes \
              --advertise-routes="''${POD_CIDR},''${SERVICE_CIDR}" \
              --reset

            echo "Tailscale is up! Node accessible at: k3s-''${NODE_NAME}"

            # Keep container running and show status
            while true; do
              sleep 300
              echo "Tailscale status:"
              tailscale status --json | jq -r '.Self.HostName + " (" + .Self.TailscaleIPs[0] + ")"' || echo "Status check failed"
            done
          '';
        };
      };
    };

    # Tailscale DaemonSet
    tailscale-daemonset = {
      content = {
        apiVersion = "apps/v1";
        kind = "DaemonSet";
        metadata = {
          name = "tailscale";
          namespace = "kube-system";
          labels = {
            app = "tailscale";
          };
        };
        spec = {
          selector = {
            matchLabels = {
              app = "tailscale";
            };
          };
          template = {
            metadata = {
              labels = {
                app = "tailscale";
              };
            };
            spec = {
              serviceAccountName = "tailscale-daemonset";
              hostNetwork = true;
              containers = [{
                name = "tailscale";
                image = "tailscale/tailscale:stable";
                command = [ "/bin/sh" "/entrypoint.sh" ];
                env = [
                  {
                    name = "TS_AUTHKEY";
                    valueFrom = {
                      secretKeyRef = {
                        name = "tailscale-auth";
                        key = "TS_AUTHKEY";
                      };
                    };
                  }
                  {
                    name = "POD_CIDR";
                    value = "10.42.0.0/16"; # Default k3s pod CIDR
                  }
                  {
                    name = "SERVICE_CIDR";
                    value = "10.43.0.0/16"; # Default k3s service CIDR
                  }
                  {
                    name = "TS_KUBE_SECRET";
                    value = "tailscale-state";
                  }
                ];
                securityContext = {
                  capabilities = {
                    add = [ "NET_ADMIN" "SYS_MODULE" ];
                  };
                  privileged = true;
                };
                volumeMounts = [
                  {
                    name = "tailscale-state";
                    mountPath = "/var/lib/tailscale";
                  }
                  {
                    name = "tailscale-sock";
                    mountPath = "/var/run/tailscale";
                  }
                  {
                    name = "entrypoint";
                    mountPath = "/entrypoint.sh";
                    subPath = "entrypoint.sh";
                  }
                ];
                resources = {
                  requests = {
                    memory = "64Mi";
                    cpu = "50m";
                  };
                  limits = {
                    memory = "128Mi";
                    cpu = "100m";
                  };
                };
              }];
              volumes = [
                {
                  name = "tailscale-state";
                  hostPath = {
                    path = "/var/lib/tailscale";
                    type = "DirectoryOrCreate";
                  };
                }
                {
                  name = "tailscale-sock";
                  hostPath = {
                    path = "/var/run/tailscale";
                    type = "DirectoryOrCreate";
                  };
                }
                {
                  name = "entrypoint";
                  configMap = {
                    name = "tailscale-entrypoint";
                    defaultMode = 493; # 0755 in decimal
                  };
                }
              ];
              tolerations = [
                {
                  operator = "Exists";
                }
              ];
            };
          };
        };
      };
    };

    # Example hello-app (without sidecar - now uses DaemonSet connectivity)
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