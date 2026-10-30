<!-- docdaemon ts:2026-10-30T02:12:50Z hash:49fb4ac299cc229b model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file is the guest-side test binary that validates k3s extras, launcher flags, and network connectivity.

The `main` function orchestrates a series of checks against the running environment, writing results to a JSON report. It verifies:

*   **Flag Contract**: Ensures `--scenario`, `--kubeconfig`, and `--namespace` match expected defaults (`/etc/manifests/k3s_extras.yaml`, `/etc/rancher/k3s/k3s.yaml`, `default`).
*   **Extra Manifests**: Polls for a specific ConfigMap marker to confirm manifests applied by `k3s_init`.
*   **Extra Files**: Validates that `/etc/fcextra/data.txt` exists, contains expected content, has permissions `0644`, and is owned by root (uid 0). This ownership check addresses previous issues where build users incorrectly owned guest files.
*   **Extra Executables**: Confirms `/opt/extra/busybox` is runnable and produces correct output.
*   **Extra Images**: Polls containerd to ensure `fctest/extra:latest` was auto-imported from the local image directory without registry access.
*   **Kube-Proxy Routing**: Verifies that ClusterIP services are routable via `net.DialTimeout`. This check relies on specific netfilter kernel modules (comment, mark, statistic) being enabled in the guest kernel to allow kube-proxy to program iptables rules correctly.

Key types include `pc` (pass condition) and `report` for structured output. Helper functions `kubectl` and `poll` abstract command execution and retry logic with timeouts.