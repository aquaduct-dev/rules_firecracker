<!-- docdaemon ts:2026-10-09T22:28:52Z hash:68b614e13d75615d model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines the build targets for Firecracker microVMs, including kernel compilation, rootfs generation tools, and integration tests for networking and k3s clusters.

### Build Targets
*   **`vmlinux`**: Compiles Linux 6.1.155 from source using host tools (`local = True`).
*   **`busybox_static` & `k3s_binary`**: Wraps external binaries to ensure executable permissions.
*   **Rootfs Tools**: Shell scripts (`mkinitramfs`, `mkrootfs`, `mkk3srootfs`, etc.) that generate various filesystem images (Debian, systemd, k3s).

### Test Infrastructure
*   **Networking Test**: `nettest_vm` boots two microVMs on a shared bridge to verify end-to-end network connectivity.
*   **K3s Cluster Test**: `k3s_cluster_vm` runs a real multi-node k3s cluster over the shared bridge, satisfying the "No stub tests" criteria.

### Exports
Publicly exports shell scripts like `cluster_run.sh` and test templates for use by external orchestrators.