# k3s-apps.nix: Auto-deployment of Kubernetes applications
{ config, pkgs, lib, role, flakeRoot, ... }:

let
  helloWorldAppManifest = pkgs.writeText "hello-world-app.yaml" ''
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: hello-world
      labels:
        app: hello-world
    spec:
      replicas: 2
      selector:
        matchLabels:
          app: hello-world
      template:
        metadata:
          labels:
            app: hello-world
        spec:
          containers:
          - name: nginx
            image: nginx:latest # Using a simple nginx image
            ports:
            - containerPort: 80
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: hello-world-service
    spec:
      selector:
        app: hello-world
      ports:
        - protocol: TCP
          port: 80       # Internal port within the cluster for this service
          targetPort: 80 # Port on the nginx pods
          nodePort: 30080 # External port accessible on each node's IP
      type: NodePort
  '';
in
{
  # This configuration will only be applied on the k3s server node
  # because k3s-apps.nix is imported in k3s-server.nix profile.
  services.k3s.manifests = [
    helloWorldAppManifest
  ];
}