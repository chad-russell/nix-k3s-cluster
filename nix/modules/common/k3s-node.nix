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
    extraFlags = lib.mkIf (role == "server") [
      "--disable traefik"
      "--disable servicelb"
      "--disable local-storage"
    ];
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

  # Tailscale for networking
  services.tailscale = {
    enable = true;
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
