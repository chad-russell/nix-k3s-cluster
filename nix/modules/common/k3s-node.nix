# k3s-node.nix: Common configuration for all k3s nodes
{ config, pkgs, lib, role, flakeRoot, ... }:

let
  # =============================================================================
  # Configuration Variables - Edit these to match your environment
  # =============================================================================
  
  # K3s cluster configuration
  k3sConfig = {
    # Tailscale DNS name of your k3s server node (replace with your actual hostname and tailnet)
    # Format: hostname.tailnet-name.ts.net
    serverHostname = "core1.tailac926.ts.net";
    apiPort = 6443;
    
    # K3s network CIDRs (these are the defaults, but now configurable)
    podCIDR = "10.42.0.0/16";      # Default k3s pod network
    serviceCIDR = "10.43.0.0/16";  # Default k3s service network
  };
  
  # Tailscale configuration
  tailscaleConfig = {
    # Tailscale network CIDR (standard Tailscale range)
    networkCIDR = "100.64.0.0/10";
    interface = "tailscale0";
    
    # Subnet routes to advertise (k3s networks)
    advertiseRoutes = [
      k3sConfig.podCIDR
      k3sConfig.serviceCIDR
    ];
  };
  
  # Computed values
  k3sServerUrl = "https://${k3sConfig.serverHostname}:${toString k3sConfig.apiPort}";
  
in
{
  imports = [ ];

  # Allow unfree packages for all nodes
  nixpkgs.config.allowUnfree = true;

  # K3s service configuration
  services.k3s = {
    enable = true;
    inherit role;
    serverAddr = lib.mkIf (role == "agent") k3sServerUrl;
    tokenFile = lib.mkIf (role == "agent") config.sops.secrets."k3s-agent-node-token".path;
  };

  sops.secrets."k3s-agent-node-token" = lib.mkIf (role == "agent") {
    sopsFile = "${flakeRoot}/secrets/k3s-agent-node-token";
    format = "binary";
    # This will expect an encrypted file at ./secrets/k3s-agent-node-token
    # relative to your flake.nix file if you don't specify a `source`.
    # Or, more explicitly, you can set:
    # source = ../secrets/k3s-agent-node-token.enc; # Adjust path as needed
    # sops-nix will decrypt it and place it at a path like /run/secrets/k3s-agent-node-token
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
      "--advertise-routes=${lib.concatStringsSep "," tailscaleConfig.advertiseRoutes}"
      "--accept-routes"  # Accept routes from other nodes
      "--ssh"            # Enable SSH access
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
    trustedInterfaces = [ tailscaleConfig.interface ];
    
    # Allow k3s API server traffic (for agents connecting to server)
    allowedTCPPorts = [ k3sConfig.apiPort ];
    
    # Additional firewall rules for k3s cluster communication
    extraCommands = ''
      # Allow traffic from Tailscale network to k3s subnets
      iptables -A nixos-fw -s ${tailscaleConfig.networkCIDR} -d ${k3sConfig.podCIDR} -j ACCEPT
      iptables -A nixos-fw -s ${tailscaleConfig.networkCIDR} -d ${k3sConfig.serviceCIDR} -j ACCEPT
      
      # Allow traffic between k3s subnets (for internal cluster communication)
      iptables -A nixos-fw -s ${k3sConfig.podCIDR} -d ${k3sConfig.serviceCIDR} -j ACCEPT
      iptables -A nixos-fw -s ${k3sConfig.serviceCIDR} -d ${k3sConfig.podCIDR} -j ACCEPT
    '';
    
    # Cleanup rules when firewall is reloaded
    extraStopCommands = ''
      # Remove our custom rules
      iptables -D nixos-fw -s ${tailscaleConfig.networkCIDR} -d ${k3sConfig.podCIDR} -j ACCEPT 2>/dev/null || true
      iptables -D nixos-fw -s ${tailscaleConfig.networkCIDR} -d ${k3sConfig.serviceCIDR} -j ACCEPT 2>/dev/null || true
      iptables -D nixos-fw -s ${k3sConfig.podCIDR} -d ${k3sConfig.serviceCIDR} -j ACCEPT 2>/dev/null || true
      iptables -D nixos-fw -s ${k3sConfig.serviceCIDR} -d ${k3sConfig.podCIDR} -j ACCEPT 2>/dev/null || true
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
