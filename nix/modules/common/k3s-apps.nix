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
      type: ClusterIP
    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: hello-world-ingress
      namespace: default # Assuming your app is in the default namespace
    spec:
      entryPoints:
        - web # Default Traefik entrypoint for HTTP
      routes:
        - match: Host(`hello-world.k3s.crussell.io`)
          kind: Rule
          services:
            - name: hello-world-service
              port: 80
  '';
in
{
  # This configuration will only be applied on the k3s server node
  # because k3s-apps.nix is imported in k3s-server.nix profile.
  services.k3s.manifests = {
    "hello-world-app" = {
      source = helloWorldAppManifest;
    };
  };
}