# K3s High Availability (3 Servers, 1 Agent) Setup Guide

This guide outlines the steps to configure your 4-node NixOS cluster into a High Availability (HA) K3s setup with 3 server nodes (`core1`, `core2`, `core3`) and 1 agent node (`core4`).

**Hostname Mapping:**
*   `core1`: Initial K3s Server (also runs workloads)
*   `core2`: Joining K3s Server (also runs workloads)
*   `core3`: Joining K3s Server (also runs workloads)
*   `core4`: K3s Agent/Worker

## Prerequisites

1.  **NixOS Configuration:** Ensure the NixOS configurations generated in the previous steps (`flake.nix`, `nix/modules/common/k3s-node.nix`) are applied.
2.  **Sops:** `sops` CLI tool is installed and configured on your management machine for encrypting secrets. Ensure your `.sops.yaml` is set up to handle `.token` files or has appropriate creation rules.
3.  **SSH Access:** You have SSH access to all nodes.
4.  **Tailscale:** Tailscale is operational on all nodes, and they can reach each other using their Tailscale hostnames (e.g., `core1`).

## Setup Steps

### Step 1: Deploy the Initial K3s Server (`core1`)

1.  **Build and Deploy `core1`:**
    ```bash
    # On your management machine
    nixos-rebuild switch --flake .#core1 --target-host core1 --use-remote-sudo
    ```
2.  **Verify K3s Initialization on `core1`:**
    *   SSH into `core1`.
    *   Check if K3s is active:
        ```bash
        sudo systemctl status k3s
        ```
    *   Wait for K3s to fully initialize. This can take a few minutes. You can monitor logs:
        ```bash
        sudo journalctl -u k3s -f
        ```
    *   Once initialized, check node status (you should see `core1` as master/control-plane and ready):
        ```bash
        sudo k3s kubectl get nodes -o wide
        ```

### Step 2: Obtain and Encrypt K3s Tokens

K3s uses a single token (often called `node-token`) that can be used by both servers to join an HA cluster and by agents to join the cluster.

1.  **Retrieve the Token from `core1`:**
    *   On `core1`, display the token:
        ```bash
        sudo cat /var/lib/rancher/k3s/server/node-token
        ```
    *   Copy this token value. Let's call it `YOUR_K3S_TOKEN`.

2.  **Encrypt the Token for Joining Servers (`k3s-server-join-token`):**
    *   On your management machine (where your flake code and `sops` are):
    *   Create a temporary file with the token:
        ```bash
        echo -n "YOUR_K3S_TOKEN" > /tmp/k3s-server-join-token
        ```
    *   Encrypt it using `sops` and place it in your flake's `secrets` directory. Adjust your sops command if you use specific key servers, age keys, PGP, etc. This example assumes your `.sops.yaml` is configured or you are using age with a key available to sops.
        ```bash
        # Example using sops default/age, assuming secrets/ is a sops-managed directory
        sops encrypt --encrypted-regex '^(data|stringData)$' -i /tmp/k3s-server-join-token > secrets/k3s-server-join-token
        ```
        Or, more generally, ensure the file `secrets/k3s-server-join-token` is created and contains the SOPS-encrypted token.
    *   Remove the temporary plaintext token file:
        ```bash
        rm /tmp/k3s-server-join-token
        ```

3.  **Encrypt the Token for Agents (`k3s-agent-node-token`):**
    *   Since the same token can be used:
    *   On your management machine:
        ```bash
        echo -n "YOUR_K3S_TOKEN" > /tmp/k3s-agent-node-token
        ```
    *   Encrypt it:
        ```bash
        sops encrypt --encrypted-regex '^(data|stringData)$' -i /tmp/k3s-agent-node-token > secrets/k3s-agent-node-token
        ```
    *   Remove the temporary plaintext token file:
        ```bash
        rm /tmp/k3s-agent-node-token
        ```
    *   **Alternatively**: If you are certain the same token value is appropriate and wish to manage only one encrypted file, you can simply copy the `secrets/k3s-server-join-token` to `secrets/k3s-agent-node-token` or have the `sopsFile` path in `k3s-node.nix` for the agent point to the same server join token file. The current Nix setup defines them as separate sops secrets, pointing to different (though potentially identically encrypted) files.

### Step 3: Deploy Joining K3s Servers (`core2`, `core3`)

1.  **Build and Deploy `core2`:**
    ```bash
    # On your management machine
    nixos-rebuild switch --flake .#core2 --target-host core2 --use-remote-sudo
    ```
2.  **Build and Deploy `core3`:**
    ```bash
    # On your management machine
    nixos-rebuild switch --flake .#core3 --target-host core3 --use-remote-sudo
    ```

3.  **Verify Cluster Status on `core1` (or any server node):**
    *   SSH into `core1`.
    *   Check the K3s service status on `core2` and `core3` if you encounter issues.
    *   After a few minutes, `core2` and `core3` should join the cluster. Verify all server nodes are present and ready:
        ```bash
        sudo k3s kubectl get nodes -o wide
        ```
        You should see `core1`, `core2`, and `core3` listed with roles including `control-plane,master`.
    *   Check etcd cluster health (K3s bundles a `k3s etcd-snapshot` command, but for live health, you might need to exec into an etcd pod or use `kubectl` against etcd if exposed, though typically K3s manages this internally):
        ```bash
        # On core1 (or any server node)
        sudo k3s kubectl get endpoints kube-etcd -n kube-system # See if all 3 servers are listed
        # For more detailed etcd health, you might need to use crictl to exec into an etcd container
        # sudo k3s crictl ps # find etcd container ID
        # sudo k3s crictl exec <ETCD_CONTAINER_ID> etcdctl endpoint health --cluster
        ```

### Step 4: Deploy the K3s Agent Node (`core4`)

1.  **Build and Deploy `core4`:**
    ```bash
    # On your management machine
    nixos-rebuild switch --flake .#core4 --target-host core4 --use-remote-sudo
    ```

2.  **Verify `core4` Joins the Cluster:**
    *   SSH into any server node (e.g., `core1`).
    *   Check the node status:
        ```bash
        sudo k3s kubectl get nodes -o wide
        ```
        You should see `core4` listed (without `control-plane,master` roles) and in a `Ready` state.
    *   Check K3s agent logs on `core4` if it doesn't join:
        ```bash
        # On core4
        sudo journalctl -u k3s -f
        ```

## Post-Setup Checks

1.  **Workload Scheduling:**
    *   By default, K3s server nodes are not tainted, meaning they can run workloads.
    *   Deploy a sample application (like the `hello-world-app` from `k3s-apps.nix`) and verify its pods are distributed across `core1`, `core2`, `core3`, and `core4`.
        ```bash
        # On any server node
        sudo k3s kubectl get pods -A -o wide
        ```
2.  **High Availability Test (Optional & Careful):**
    *   To test HA, you could try stopping the K3s service on the current leader (e.g., `core1` if it was the first one up) and see if another server takes over. The Kubernetes API should remain accessible via the remaining server nodes.
        ```bash
        # On core1 (example)
        # sudo systemctl stop k3s
        ```
    *   Then, try accessing the cluster from another server node (`core2` or `core3`):
        ```bash
        # On core2
        # sudo k3s kubectl get nodes
        ```
    *   **Remember to restart K3s on `core1` afterwards:**
        ```bash
        # On core1
        # sudo systemctl start k3s
        ```
    *   **Caution:** Be mindful when testing HA, as it can disrupt workloads.

## Troubleshooting Tips

*   **Token Issues:**
    *   "connection refused" or "unauthorized": Double-check that the correct token (from `/var/lib/rancher/k3s/server/node-token` on an active server) was used and correctly decrypted by `sops-nix` on the joining nodes.
    *   Ensure `tokenFile` paths in `k3s-node.nix` resolve correctly to the sops-decrypted token path (usually in `/run/secrets/`).
*   **Network Connectivity:**
    *   Ensure Tailscale is running on all nodes and they can ping each other by their Tailscale hostnames.
    *   Verify firewall rules (configured in `k3s-node.nix` and `common-base.nix`) are not blocking necessary K3s ports (6443/tcp for API, 10250/tcp for kubelet, etc., and flannel/VXLAN ports if applicable).
    *   The `serverAddr` in `k3s-node.nix` (`https://core1:6443`) must be resolvable and reachable from joining servers and agents.
*   **K3s Logs:**
    *   Server logs: `sudo journalctl -u k3s -f` on server nodes.
    *   Agent logs: `sudo journalctl -u k3s -f` on agent nodes.
*   **Sops Issues:**
    *   If secrets are not decrypting, check `sops-nix` service logs or try decrypting manually with `sops -d <secret_file>` on a machine with the necessary decryption keys.
    *   Ensure `sops.age.keyFile` in `flake.nix` points to a valid age private key on each node.
*   **`clusterInit` and `serverAddr`:**
    *   Only `core1` (the initial server) should have `clusterInit = true`.
    *   `core2`, `core3` (joining servers) and `core4` (agent) must have `serverAddr` set to point to an active server (initially `core1`).
    *   Joining servers (`core2`, `core3`) must *not* have `clusterInit = true`.
*   **Existing K3s Installations:** If these nodes had K3s installed previously in a different configuration, ensure old data in `/var/lib/rancher/k3s` is cleaned up if you're starting fresh, or be aware it might try to rejoin with old state. A NixOS rebuild should manage the service, but on-disk data might persist.

This guide should help you through the setup process. Remember to adapt SOPS commands and paths if your specific `sops` setup differs. 