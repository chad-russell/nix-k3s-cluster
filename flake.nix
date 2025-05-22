{
  description = "NixOS k3s cluster flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    disko.url = "github:nix-community/disko";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    colmena.url = "github:zhaofengli/colmena";
  };

  outputs = { self, nixpkgs, flake-utils, disko, sops-nix, colmena, ... }:
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
            sops-nix.nixosModules.sops
            {
              networking.hostName = hostname;
              sops.age.keyFile = "/etc/sops/age/key.txt";
              sops.age.generateKey = false;
            }
          ];
        };

    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        devShell = pkgs.mkShell {
          buildInputs = [ pkgs.k3s pkgs.kubectl pkgs.sops pkgs.age pkgs.colmena ];
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
                  ];
                  specialArgs = { role = node.role; flakeRoot = ./.; };
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
                    ./modules/common-base.nix
                    sops-nix.nixosModules.sops
                    ./modules/k3s-node.nix
                  ];
                  specialArgs = { role = node.role; flakeRoot = ./.; };
                };
              }
            ]
          ) nodes
        )
      );
      # Colmena Hive Configuration
      colmenaHive = colmena.lib.makeHive (
        {
          meta = {
            nixpkgs = import nixpkgs { system = "x86_64-linux"; };
            # Define nodeSpecialArgs here for Colmena to pass to each node's modules
            nodeSpecialArgs = builtins.listToAttrs (map (node: {
              name = node.name;
              value = { # These are the special arguments for this specific node
                role = node.role;
                flakeRoot = ./.;
              };
            }) nodes);
          };
        } // builtins.listToAttrs (map (node: {
          name = node.name;
          # Node definition is now simpler. SpecialArgs are handled by meta.nodeSpecialArgs.
          value = {
            imports = [
              disko.nixosModules.disko
              (./modules + "/${node.name}/disko.nix")
              ./modules/common-base.nix
              sops-nix.nixosModules.sops
              ./modules/k3s-node.nix
            ];
            # Colmena-specific deployment options for this node.
            deployment.targetHost = node.name;
            deployment.targetUser = "root";
          };
        }) nodes)
      );
    };
}
