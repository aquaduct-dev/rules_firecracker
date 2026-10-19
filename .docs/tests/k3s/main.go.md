<!-- docdaemon ts:2026-10-19T23:24:33Z hash:7d3e73dd08bd2642 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file is the guest-side test binary that validates K3s extras and launcher flag contracts.

It verifies that `firecracker_k3s_test` attributes are correctly applied inside the VM. The `main` function parses flags for scenario, kubeconfig, and namespace, then runs a series of checks against these expectations.

**Key Checks:**
*   **Flags:** Ensures `--scenario`, `--kubeconfig`, and `--namespace` match the launcher's contract.
*   **Extra Manifests:** Polls for a specific ConfigMap marker to confirm manifests were applied by `k3s_init`.
*   **Extra Files:** Validates that `/etc/fcextra/data.txt` has correct content, permissions (`0644`), and ownership (`root:root`). This ownership check exists because build tools previously preserved the build user's UID; post-formatting scripts now explicitly re-own inodes to `0:0`.
*   **Extra Execs:** Runs `/opt/extra/busybox` to verify executables are runnable with `0755` permissions.
*   **Extra Images:** Polls containerd to ensure images from `/var/lib/rancher/k3s/agent/images` are auto-imported without registry access.

Results are written to a JSON report at `reportPath`. The process exits non-zero if any pass condition fails.