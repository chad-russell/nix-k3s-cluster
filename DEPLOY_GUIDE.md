# NixOS K3s Cluster Deployment Guide

This guide outlines the steps to deploy and manage your K3s cluster using NixOS, `nixos-anywhere`, and `sops-nix` for secret management.

## Prerequisites

1.  **Local Machine Setup**:
    *   Ensure you have `nix` (with flake support), `git`, `sops`, and `age` installed.
        *   You can get `sops` and `age` in a temporary shell: `nix-shell -p sops age`
    *   Clone your NixOS flake repository (e.g., `talos`).
    *   Your SSH public key should be in `modules/common-base.nix` for root access.

2.  **K3s Server Node (`core1`) Token**:
    *   Ensure your `core1` (K3s server) node is already deployed and running.
    *   Retrieve the K3s server node token. SSH into `core1` and run:
        ```bash
        sudo cat /var/lib/rancher/k3s/server/node-token
        ```
    *   This token will be used for agent nodes.

## Initial SOPS Setup (One-Time for your Flake Admin)

This needs to be done once to initialize SOPS for your flake repository.

1.  **Generate Admin `age` Key**:
    *   If you don't have one already, generate an `age` key pair for yourself (the administrator of this flake).
        ```bash
        mkdir -p ~/.config/sops/age
        age-keygen -o ~/.config/sops/age/keys.txt
        ```
    *   Note the **public key** that `age-keygen` outputs (it starts with `age1...`).

2.  **Create `.sops.yaml`**:
    *   In the root of your flake repository, create a `.sops.yaml` file.
    *   Add your admin public key. This allows you to encrypt/decrypt secrets.
        ```yaml
        # .sops.yaml
        version: 1
        keys:
          - &admin_key YOUR_ADMIN_PUBLIC_AGE_KEY_HERE # Paste your public age key
        creation_rules:
          # Encrypt *.yaml files in secrets/ for admin and any host tagged with 'hosts_group'
          - path_regex: .*/secrets/.*\.yaml$
            encrypted_regex: ^(data|stringData)$
            pgp: "" # Clear PGP if only using age
            key_groups:
              - age:
                - *admin_key
                # Add more keys/groups as needed, e.g. a group for all hosts

          # Specific rule for the k3s agent node token
          - path_regex: .*/secrets/k3s-agent-node-token$
            pgp: ""
            # Initially, this might only be encrypted for admin, or an empty group.
            # Host keys will be added to this rule as nodes are provisioned.
            key_groups:
              - age:
                - *admin_key
                # Host keys will be added here, e.g. *core2_key, *core3_key
        ```
    *   Commit `.sops.yaml` to your repository.

## Deploying a New K3s Agent Node (e.g., `core2`)

Repeat these steps for each new agent node (`core3`, `core4`, etc.), replacing `core2` with the appropriate hostname.

**Phase 1: Bootstrap Minimal NixOS**

1.  **Provision with `nixos-anywhere`**:
    *   Ensure the target machine is booted into the NixOS installer environment (e.g., from a NixOS ISO).
    *   From your flake repository directory on your management machine:
        ```bash
        nixos-anywhere --flake github:chad-russell/nix-k3s-cluster/main github:chad-russell/nixx-k3s-cluster/main#core2-bootstrap nixos@<core2_ip_address>
        ```
    *   Wait for the installation to complete and the node to reboot.

2.  **Generate and Configure Host SOPS Key on the New Node**:
    *   SSH into the newly provisioned node (e.g., `ssh root@<core2_ip_address>`):
    *   Create the SOPS age key directory and generate the host's unique key:
        ```bash
        sudo mkdir -p /etc/sops/age
        sudo age-keygen -o /etc/sops/age/key.txt
        sudo chmod 0600 /etc/sops/age/key.txt
        sudo chown root:root /etc/sops/age/key.txt
        ```
    *   Get the **public key** for this host:
        ```bash
        sudo age-keygen -y /etc/sops/age/key.txt
        ```
    *   **Important**: Copy this public key (starts with `age1...`). You'll need it in the next step.

**Phase 2: Configure SOPS & Deploy Full K3s Configuration**

1.  **Update `.sops.yaml` with the New Host Key (on your management machine)**:
    *   Edit `.sops.yaml` in your flake repository.
    *   Add a new key entry for the node (e.g., `core2_key`) and add it to the `key_groups` for the `k3s-agent-node-token` (and any other relevant secrets).
        ```yaml
        # .sops.yaml (snippet)
        keys:
          - &admin_key YOUR_ADMIN_PUBLIC_AGE_KEY_HERE
          - &core2_key CORE2_PUBLIC_AGE_KEY_YOU_JUST_COPIED # Add core2's key
          # Add &core3_key etc. as you provision more nodes

        creation_rules:
          # ... other rules ...
          - path_regex: .*/secrets/k3s-agent-node-token$
            pgp: ""
            key_groups:
              - age:
                - *admin_key
                - *core2_key # Ensure core2_key is added here
                # Add other host keys like *core3_key as they are provisioned
        ```

2.  **Create/Update and Encrypt the `k3s-agent-node-token` Secret (on your management machine)**:
    *   If you haven't already, create the plain-text token file:
        ```bash
        mkdir -p secrets
        echo "YOUR_K3S_SERVER_TOKEN_FROM_PREREQUISITES" > secrets/k3s-agent-node-token
        ```
    *   Encrypt (or re-encrypt if it exists) the token file with SOPS. This will use the updated `.sops.yaml` and encrypt it for all specified keys (admin and all relevant hosts).
        ```bash
        sops --encrypt --in-place secrets/k3s-agent-node-token
        ```
        Alternatively, to update keys for an existing encrypted file:
        ```bash
        sops updatekeys -y secrets/k3s-agent-node-token
        ```
    *   Commit the changes to `.sops.yaml` and the (re-)encrypted `secrets/k3s-agent-node-token` to your repository.

3.  **Deploy the Full Configuration to the Node**:
    *   SSH into the target node (`core2`).
    *   Navigate to your flake checkout (or `scp` it over if not already there).
    *   Run `nixos-rebuild switch` using the node's full configuration (not the bootstrap one):
        ```bash
        sudo nixos-rebuild switch --flake /path/to/your/flake/checkout#core2
        ```
        (Replace `/path/to/your/flake/checkout` with the actual path to your flake on the node, e.g., `./` if you are in the flake root).
    *   The k3s agent service should now start and register with the server using the decrypted token.

## Updating Secrets or Adding New Secrets

1.  Modify the plain-text secret file in your `secrets` directory.
2.  Re-encrypt it using `sops --encrypt --in-place secrets/your-secret-file`.
3.  Commit the encrypted file.
4.  Run `sudo nixos-rebuild switch --flake github:chad-russell/nix-k3s-cluster/main#<nodeName> --refresh` on each affected node.

## Updating Host Keys (e.g., if a host is re-provisioned)

1.  Generate a new key on the host (Phase 1, Step 2).
2.  Replace the old public key with the new one in `.sops.yaml`.
3.  Run `sops updatekeys -y <path-to-secret>` for all secrets that were encrypted with the old key.
4.  Commit changes and redeploy.

## Troubleshooting & Best Practices

### 1. **sops-nix: Secret Format**
- For simple secrets (like tokens), the secret file should be **plain text** (not YAML/JSON) before encryption.
- In your Nix config, set:
  ```nix
  sops.secrets."your-secret" = {
    sopsFile = "${flakeRoot}/secrets/your-secret";
    format = "binary";
  };
  ```
- If you want to use YAML/JSON, specify `format` and `key` accordingly.
- If you see errors about missing keys, double-check the file format and the `format` option.
- If you get an error about the key not being correct, make sure you are using the correct master key for nix-k3s-cluster
  - This is different than the key for desktop/home-manager flake. Find it in bitwarden
  - Save it and do something like the following: `export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys-core.txt"`

### 2. **Disko: Partitioning and Mounting**
- `nixos-rebuild switch` **does not** partition or format disks. You must run disko manually:
  ```sh
  nix run github:nix-community/disko -- --mode disko --flake github:chad-russell/nix-k3s-cluster/main .#<hostname> --refresh
  ```
- Always run this from your local flake checkout, not a remote flake reference.
- **WARNING:** This will destroy all data on the target disks as defined in your disko config.
- After running disko, reboot or manually mount all partitions as defined in your config.

### 3. **Mounting /boot**
- If you see errors about `/boot` not being mounted, manually mount it:
  ```sh
  mount /dev/<boot-partition> /boot
  ```
- Use `lsblk` to find the correct partition (usually something like `/dev/nvme0n1p1`).
- If `/boot` does not exist, create it: `mkdir -p /boot`

### 4. **Bootloader Installation**
- After repartitioning, the EFI System Partition (ESP) may be empty.
- If you see errors about systemd-boot not being installed, run:
  ```sh
  bootctl install
  ```
- Then re-run `nixos-rebuild switch`.

### 5. **General Recovery Steps**
- If you end up in an emergency shell:
  1. Use `journalctl -xb` and `systemctl --failed` to find the real cause (often a mount or secret issue).
  2. Use `lsblk` and `mount` to check partition status.
  3. Mount missing partitions as needed.
  4. Fix the root cause (partition, secret, config), then re-run `nixos-rebuild switch`.

### 6. **Best Practices**
- Always keep a local flake checkout on each node for recovery.
- After running disko, reboot or manually mount all new partitions before rebuilding.
- For sops-nix, always specify `format = "binary"` for plaintext secrets.
- Document device names and partitioning schemes for each node.
- If you change disk layout, always re-run disko and reinstall the bootloader.

_This section is based on real-world troubleshooting and will help you avoid and recover from common pitfalls in future deployments._

This guide should help you manage your cluster deployments consistently! 