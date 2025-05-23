# k3s-node.nix: Common configuration for all k3s nodes
{ config, pkgs, lib, role, flakeRoot, initialServer, ... }:

let
  # Configuration variables - centralized for easy maintenance
  k3sConfig = {
    # K3s server configuration
    server = {
      hostname = "core1";  # Tailscale hostname of the k3s server
      port = 6443;         # K3s API server port
    };
    
    # Network CIDRs
    networks = {
      pods = "10.42.0.0/16";      # Pod CIDR
      services = "10.43.0.0/16";  # Service CIDR
    };
  };
  
  # Tailscale configuration
  tailscale = {
    network = "100.64.0.0/10";  # Tailscale network CIDR
    interface = "tailscale0";   # Tailscale interface name
  };

  # Construct the k3s server URL using Tailscale DNS
  k3sServerUrl = "https://${k3sConfig.server.hostname}:${toString k3sConfig.server.port}";
in

{
  imports = [ ];

  # Allow unfree packages for all nodes
  nixpkgs.config.allowUnfree = true;

  # K3s service configuration
  services.k3s = {
    enable = true;
    inherit role;
    # Set clusterInit for the initial server node
    clusterInit = lib.mkIf (role == "server" && initialServer) true;
    # Server address is needed for agents and joining servers
    serverAddr = lib.mkIf (role == "agent" || (role == "server" && !initialServer)) k3sServerUrl;
    # Token file is needed for agents and joining servers, using a single common token
    tokenFile = lib.mkIf (role == "agent" || (role == "server" && !initialServer))
                  config.sops.secrets."k3s-node-token".path;
    extraFlags = [ "--flannel-iface=${tailscale.interface}" ];
  };

  sops.secrets."k3s-node-token" = lib.mkIf (role == "agent" || (role == "server" && !initialServer)) {
    sopsFile = "${flakeRoot}/secrets/k3s-node-token";
    format = "binary";
    # This will expect an encrypted file at ./secrets/k3s-node-token
    # relative to your flake.nix file.
    # Ensure k3s user (typically root or k3s) can read it.
    # Default owner is root, default mode is 0400 if not specified.
    # owner = config.services.k3s.user;
    # group = config.services.k3s.group;
    # mode = "0400"; # Read-only by owner
  };

  # Tailscale for networking with k3s subnet routing
  services.tailscale = {
    enable = true;
    # Declaratively configure Tailscale to advertise k3s subnets
    extraUpFlags = [
      "--advertise-routes=${k3sConfig.networks.pods},${k3sConfig.networks.services}"  # k3s pod and service CIDRs
      "--accept-routes"                                                   # Accept routes from other nodes
      "--ssh"                                                             # Enable SSH access
    ];
    # Enable IP forwarding for subnet routing
    useRoutingFeatures = "server";
  };

  # Explicitly enable IP forwarding (in case of conflicts)
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  # Firewall configuration for Tailscale and k3s
  networking.firewall = {
    # Allow traffic on the Tailscale interface
    trustedInterfaces = [ tailscale.interface ];
    
    # Allow k3s API server traffic (for agents connecting to server)
    allowedTCPPorts = [ k3sConfig.server.port ];
    
    # Additional firewall rules for k3s cluster communication
    extraCommands = ''
      # Allow traffic from Tailscale network to k3s subnets
      iptables -A nixos-fw -s ${tailscale.network} -d ${k3sConfig.networks.pods} -j ACCEPT
      iptables -A nixos-fw -s ${tailscale.network} -d ${k3sConfig.networks.services} -j ACCEPT
      
      # Allow traffic between k3s subnets (for internal cluster communication)
      iptables -A nixos-fw -s ${k3sConfig.networks.pods} -d ${k3sConfig.networks.services} -j ACCEPT
      iptables -A nixos-fw -s ${k3sConfig.networks.services} -d ${k3sConfig.networks.pods} -j ACCEPT
    '';
    
    # Cleanup rules when firewall is reloaded
    extraStopCommands = ''
      # Remove our custom rules
      iptables -D nixos-fw -s ${tailscale.network} -d ${k3sConfig.networks.pods} -j ACCEPT 2>/dev/null || true
      iptables -D nixos-fw -s ${tailscale.network} -d ${k3sConfig.networks.services} -j ACCEPT 2>/dev/null || true
      iptables -D nixos-fw -s ${k3sConfig.networks.pods} -d ${k3sConfig.networks.services} -j ACCEPT 2>/dev/null || true
      iptables -D nixos-fw -s ${k3sConfig.networks.services} -d ${k3sConfig.networks.pods} -j ACCEPT 2>/dev/null || true
    '';
  };

  # Common system packages
  environment.systemPackages = with pkgs; [
    k3s kubectl
  ];

  # NixOS state version
  system.stateVersion = "24.11";

  # Use systemd-boot for UEFI systems (best practice for modern NixOS)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
