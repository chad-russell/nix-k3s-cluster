# k3s-node.nix: Common configuration for all k3s nodes
{ config, pkgs, lib, role, flakeRoot, ... }:

{
  imports = [ ];

  # Allow unfree packages for all nodes
  nixpkgs.config.allowUnfree = true;

  # K3s service configuration
  services.k3s = {
    enable = true;
    inherit role;
    serverAddr = lib.mkIf (role == "agent") "https://100.103.44.81:6443"; # core1 Tailscale static IP
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
      "--advertise-routes=10.42.0.0/16,10.43.0.0/16"  # k3s pod and service CIDRs
      "--accept-routes"                                # Accept routes from other nodes
      "--ssh"                                          # Enable SSH access (matches current config)
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
    trustedInterfaces = [ "tailscale0" ];
    
    # Allow k3s API server traffic (for agents connecting to server)
    allowedTCPPorts = [ 6443 ];
    
    # Additional firewall rules for k3s cluster communication
    extraCommands = ''
      # Allow traffic from Tailscale network (100.64.0.0/10) to k3s subnets
      iptables -A nixos-fw -s 100.64.0.0/10 -d 10.42.0.0/16 -j ACCEPT
      iptables -A nixos-fw -s 100.64.0.0/10 -d 10.43.0.0/16 -j ACCEPT
      
      # Allow traffic between k3s subnets (for internal cluster communication)
      iptables -A nixos-fw -s 10.42.0.0/16 -d 10.43.0.0/16 -j ACCEPT
      iptables -A nixos-fw -s 10.43.0.0/16 -d 10.42.0.0/16 -j ACCEPT
    '';
    
    # Cleanup rules when firewall is reloaded
    extraStopCommands = ''
      # Remove our custom rules
      iptables -D nixos-fw -s 100.64.0.0/10 -d 10.42.0.0/16 -j ACCEPT 2>/dev/null || true
      iptables -D nixos-fw -s 100.64.0.0/10 -d 10.43.0.0/16 -j ACCEPT 2>/dev/null || true
      iptables -D nixos-fw -s 10.42.0.0/16 -d 10.43.0.0/16 -j ACCEPT 2>/dev/null || true
      iptables -D nixos-fw -s 10.43.0.0/16 -d 10.42.0.0/16 -j ACCEPT 2>/dev/null || true
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
