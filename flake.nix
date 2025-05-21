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
                    # Minimal modules for bootstrap
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
      colmenaHive = colmena.lib.makeHive {
        meta = {
          # Passing nixpkgs to Colmena
          nixpkgs = import nixpkgs { system = "x86_64-linux"; };
          # You can also pass overlays or other nixpkgs options here if needed
        };
        nodes = builtins.listToAttrs (map (node: {
          name = node.name; # Use the node name as the attribute name for Colmena
          value = { pkgs, ... }: { # pkgs is passed by Colmena
            imports = [
              ./modules/common-base.nix
              sops-nix.nixosModules.sops
              (./modules + "/${node.name}/disko.nix")
              ./modules/k3s-node.nix
            ];
            networking.hostName = node.name;
            sops.age.keyFile = "/etc/sops/age/key.txt"; # Ensure this path is correct and accessible
            sops.age.generateKey = false;

            # Pass specialArgs to the modules, Colmena makes them available
            # The actual NixOS configuration (services.k3s, etc.) will come from the imported modules
            # using these specialArgs.
            # Example: config.services.k3s.role will use `specialArgs.role`
            specialArgs = { inherit (node) role; flakeRoot = ./.; };

            # Deployment target configuration (adjust as necessary)
            deployment.targetHost = node.name; # Using node.name directly (tailscale Magic DNS will resolve it)
            deployment.targetUser = "root"; # Assuming deployment as root
            # deployment.targetPort = 22; # Default is 22

            # If you have specific SSH keys for deployment, configure them here or use ssh-agent
            # deployment.sshOpts = [ "-i" "/path/to/deployment_key" ];

            # For sops-nix, ensure the age key is available on the target during activation
            # This is handled by sops.age.keyFile above and your sops-nix setup.
          };
        }) nodes);
      };
    };
}
