# K3s agent node profile
{ config, lib, pkgs, ... }:

{
  imports = [
    ../modules/common/k3s-node.nix
  ];

  # K3s-specific configurations for agent nodes
  services.k3s = {
    role = "agent";
    
    # The server URL should be set in the node-specific configuration
    # or via a flake argument
    
    extraFlags = toString [
      # Agent-specific flags can be added here
      "--flannel-backend=host-gw"
    ];
  };

  # Networking settings
  networking.firewall.allowedTCPPorts = [ 
    10250 # Kubelet
  ];
  
  networking.firewall.allowedUDPPorts = [
    8472  # Flannel VXLAN
  ];

  # Less resource-intensive tools for agent nodes
  environment.systemPackages = with pkgs; [
    kubectl
    jq
  ];
} 