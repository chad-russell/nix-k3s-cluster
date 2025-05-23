# k3s-apps.nix: Auto-deployment of Kubernetes applications
{ config, pkgs, lib, role, flakeRoot, ... }:

{
  # This configuration will only be applied on the k3s server node
  # because k3s-apps.nix is imported in k3s-server.nix profile.
  services.k3s.manifests = {
    "test-minimal-app" = {
      content = [ # Using a list, as the original error was for a "doc"
        {
          apiVersion = "v1";
          kind = "ConfigMap";
          metadata = {
            name = "test-configmap";
            namespace = "default";
          };
          data = {
            exampleKey = "exampleValue";
          };
        }
      ];
    };
  };
}