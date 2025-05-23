# NixOS Configuration

This directory contains all NixOS configurations for the cluster nodes.

## Directory Structure

- **modules/**: NixOS modules
  - **common/**: Shared configurations across all nodes
  - **hosts/**: Host-specific configurations like disko partitioning
- **profiles/**: Reusable profiles for different node types
  - **k3s-server.nix**: Profile for K3s server nodes
  - **k3s-agent.nix**: Profile for K3s agent nodes
- **pkgs/**: Custom packages

## Usage

See the main flake.nix and deployment guide for instructions on how to use these configurations. 