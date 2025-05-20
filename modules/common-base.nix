# modules/common-base.nix
# Common configuration for all nodes, bootstrap or full.
{ pkgs, lib, config, ... }:

{
  imports = [ ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Tailscale for networking (useful for both bootstrap and app stages)
  services.tailscale.enable = true;

  # OpenSSH Server Configuration
  services.openssh = {
    enable = true; # SSH enabled by default
    settings = {
      PasswordAuthentication = false; # Disable password authentication for SSH
      PermitRootLogin = "prohibit-password"; # Allow root login with key only, not password
    };
  };

  # Root SSH key for all nodes
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV3uwBB9upyKmXD/M5U1cFDvY6sSnINHxaqXp7/IoEHsXzHKmR5yhGLVszMzMlINBTxrWEYbjzNJPEvWeLCt3EbU4LPVffc8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
  ];
  # Root password for local console access
  users.users.root.hashedPassword = "$6$NrcWIXntX/mytgFj$9Sa/VuZGCapVG2mzoRv5lyGyVT3b49CkHFpU0iqa6LpcoR6Sj5SPAzd7TQO76N6wBhIjbf9LtTOWe.35SJayG/";

  # NixOS state version
  system.stateVersion = "24.11";

  # Use systemd-boot for UEFI systems
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
} 