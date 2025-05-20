# k3s-node.nix: Common configuration for all k3s nodes
{ config, pkgs, lib, role, ... }:

{
  imports = [ ];

  # Allow unfree packages for all nodes
  nixpkgs.config.allowUnfree = true;

  # K3s service configuration
  services.k3s = {
    enable = true;
    inherit role; # "server" or "agent"
    extraFlags = lib.mkIf (role == "server") [
      "--disable traefik"
      "--disable servicelb"
      "--disable local-storage"
    ];
    serverAddr = lib.mkIf (role == "agent") "https://100.104.34.1:6443"; # Static tailscale IP for server
    tokenFile = lib.mkIf (role == "agent") config.sops.secrets."k3s-agent-node-token".path; # Use sops-nix path
  };

  sops.secrets."k3s-agent-node-token" = lib.mkIf (config.services.k3s.role == "agent") {
    sopsFile = ../../secrets/k3s-agent-node-token;
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

  # Root SSH key for all nodes
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV3uwBB9upyKmXD/M5U1cFDvY6sSnINHxaqXp7/IoEHsXzHKmR5yhGLVszMzMlINBTxrWEYbjzNJPEvWeLCt3EbU4LPVffc8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
  ];
  # Set the root password hash below. Generate with: mkpasswd -m sha-512 OR openssl passwd -6
  users.users.root.hashedPassword = "$6$NrcWIXntX/mytgFj$9Sa/VuZGCapVG2mzoRv5lyGyVT3b49CkHFpU0iqa6LpcoR6Sj5SPAzd7TQO76N6wBhIjbf9LtTOWe.35SJayG/";

  # NixOS state version
  system.stateVersion = "24.11";

  # Use systemd-boot for UEFI systems (best practice for modern NixOS)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
