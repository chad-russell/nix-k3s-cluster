{
  description = "NixOS k3s cluster flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    disko.url = "github:nix-community/disko";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, disko, sops-nix, ... }:
    let
      nodes = [
        { name = "core1"; role = "server"; }
        { name = "core2"; role = "agent"; }
        { name = "core3"; role = "agent"; }
        { name = "core4"; role = "agent"; }
      ];

      # Helper function to generate a NixOS system configuration
      mkSystem = { hostname, system, extraModules, specialArgs ? {} }:
        nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = extraModules ++ [
            ./modules/common-base.nix
            sops-nix.nixosModules.sops # sops is needed for both stages (host key management for bootstrap)
            {
              networking.hostName = hostname;
              sops.defaultSopsFile = null; # Explicitly set to null
              sops.age.keyFile = "/etc/sops/age/key.txt";
              sops.age.generateKey = false; # We will generate manually
            }
          ];
        };

    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        devShell = pkgs.mkShell {
          buildInputs = [ pkgs.k3s pkgs.kubectl pkgs.sops pkgs.age ];
        };
      }
    ) // {
      nixosConfigurations = builtins.listToAttrs (
        # Generate bootstrap and full configurations for each node
        builtins.concatLists (
          map (
            node: [
              {
                name = "${node.name}-bootstrap";
                value = mkSystem {
                  hostname = node.name;
                  system = "x86_64-linux";
                  extraModules = [
                    disko.nixosModules.disko
                    (./modules + "/${node.name}/disko.nix")
                    # Minimal modules for bootstrap
                  ];
                  specialArgs = { role = node.role; };
                };
              }
              {
                name = node.name;
                value = mkSystem {
                  hostname = node.name;
                  system = "x86_64-linux";
                  extraModules = [
                    disko.nixosModules.disko
                    (./modules + "/${node.name}/disko.nix")
                    ./modules/k3s-node.nix
                  ];
                  specialArgs = { role = node.role; };
                };
              }
            ]
          ) nodes
        )
      );
    };
}
