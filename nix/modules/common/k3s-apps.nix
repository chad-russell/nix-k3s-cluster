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

  # Create the secret manifest using sops templates
  sops.templates."tailscale-secret" = lib.mkIf isServer {
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
    path = "/var/lib/rancher/k3s/server/manifests/tailscale-secret.json";
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

    # Tailscale ServiceAccount
    tailscale-serviceaccount = {
      content = {
        apiVersion = "v1";
        kind = "ServiceAccount";
        metadata = {
          name = "tailscale";
          namespace = "applications";
        };
      };
    };

    # Tailscale Role
    tailscale-role = {
      content = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "Role";
        metadata = {
          namespace = "applications";
          name = "tailscale";
        };
        rules = [
          {
            apiGroups = [ "" ];
            resources = [ "secrets" ];
            verbs = [ "create" "get" "update" "patch" ];
          }
          {
            apiGroups = [ "" ];
            resources = [ "events" ];
            verbs = [ "create" "get" "patch" ];
          }
        ];
      };
    };

    # Tailscale RoleBinding
    tailscale-rolebinding = {
      content = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "RoleBinding";
        metadata = {
          name = "tailscale";
          namespace = "applications";
        };
        subjects = [{
          kind = "ServiceAccount";
          name = "tailscale";
          namespace = "applications";
        }];
        roleRef = {
          kind = "Role";
          name = "tailscale";
          apiGroup = "rbac.authorization.k8s.io";
        };
      };
    };

    # Hello app with Tailscale sidecar
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
              serviceAccountName = "tailscale";
              containers = [
                # Main hello-app container
                {
                  name = "hello-app";
                  image = "gcr.io/google-samples/hello-app:1.0";
                  ports = [{ containerPort = 8080; }];
                  env = [{ name = "PORT"; value = "8080"; }];
                }
                # Tailscale sidecar container
                {
                  name = "tailscale";
                  image = "tailscale/tailscale:latest";
                  env = [
                    {
                      name = "TS_AUTHKEY";
                      valueFrom.secretKeyRef = {
                        name = "tailscale-auth";
                        key = "TS_AUTHKEY";
                      };
                    }
                    {
                      name = "TS_HOSTNAME";
                      value = "hello-app-k3s";
                    }
                    {
                      name = "TS_STATE_DIR";
                      value = "/var/lib/tailscale";
                    }
                    {
                      name = "TS_USERSPACE";
                      value = "false";
                    }
                    {
                      name = "TS_SERVE_CONFIG";
                      value = builtins.toJSON {
                        TCP = {
                          "443" = { HTTPS = true; };
                          "80" = { HTTP = true; };
                        };
                        Web = {
                          "hello-app-k3s:443" = {
                            Handlers = {
                              "/" = { Proxy = "http://127.0.0.1:8080"; };
                            };
                          };
                          "hello-app-k3s:80" = {
                            Handlers = {
                              "/" = { Proxy = "http://127.0.0.1:8080"; };
                            };
                          };
                        };
                      };
                    }
                  ];
                  securityContext.capabilities.add = [ "NET_ADMIN" ];
                  volumeMounts = [{
                    name = "tailscale-state";
                    mountPath = "/var/lib/tailscale";
                  }];
                }
              ];
              volumes = [{
                name = "tailscale-state";
                emptyDir = {};
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