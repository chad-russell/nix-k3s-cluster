# K3s server node profile
{ config, lib, pkgs, ... }:

{
  imports = [
    ../modules/common/k3s-node.nix
    ../modules/common/k3s-apps.nix
  ];

  # K3s-specific configurations for server nodes
  services.k3s = {
    role = "server";
    extraFlags = [
      # Server-specific flags
      "--disable-cloud-controller"
      "--disable=local-storage"
      # NOTE: --flannel-backend flag has been deprecated in k3s 1.31+
      # Flannel backend is now configured via CNI configuration if needed
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