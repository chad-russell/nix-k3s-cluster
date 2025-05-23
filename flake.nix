{
  description = "NixOS k3s cluster flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.05";
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
            ./nix/modules/common/common-base.nix
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
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [ 
            k3s 
            kubectl 
            sops 
            age 
            kubernetes-helm
            kustomize
          ];
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
                    (./nix/modules/hosts + "/${node.name}/disko.nix")
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
                    (./nix/modules/hosts + "/${node.name}/disko.nix")
                    ./nix/modules/common/common-base.nix
                    sops-nix.nixosModules.sops
                    (if node.role == "server" then ./nix/profiles/k3s-server.nix else ./nix/profiles/k3s-agent.nix)
                  ];
                  specialArgs = { role = node.role; flakeRoot = ./.; };
                };
              }
            ]
          ) nodes
        )
      );
    };
}
