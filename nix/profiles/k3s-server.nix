# K3s server node profile
{ config, lib, pkgs, ... }:

{
  imports = [
    ../modules/common/k3s-node.nix
  ];

  # K3s-specific configurations for server nodes
  services.k3s = {
    role = "server";
    extraFlags = toString [
      # Server-specific flags can be added here
      "--disable-cloud-controller"
      "--disable=traefik"  # Use your own ingress controller
      "--flannel-backend=host-gw"  # Better performance than vxlan
    ];
  };

  # Networking settings
  networking.firewall.allowedTCPPorts = [ 
    6443  # Kubernetes API
    8472  # Flannel VXLAN
    10250 # Kubelet
  ];
  
  networking.firewall.allowedUDPPorts = [
    8472  # Flannel VXLAN
  ];

  # Let's pre-install some useful tools for K3s management
  environment.systemPackages = with pkgs; [
    kubectl
    k9s       # TUI for Kubernetes
    kubectx   # For switching contexts easily
    helm      # Kubernetes package manager
    jq        # JSON processor
  ];
} 