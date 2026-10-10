<!-- docdaemon ts:2026-10-10T19:05:18Z hash:841b95cc8ce7fbbd model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file implements Bazel macros for building and running Firecracker microVMs, including initramfs/rootfs generation, container booting, and various integration tests.

It provides public-facing rules like `firecracker_microvm` to launch VMs with kernels and disk images, and `firecracker_container` to run OCI images as guests. It also defines test helpers: `firecracker_test` for single-VM assertions, and cluster tests (`firecracker_cluster_test`, `firecracker_renumber_test`, `firecracker_install_cluster_test`) for multi-node networking and installation scenarios.

Key implementation details include:
*   **Rootfs/Initramfs Builders**: `firecracker_initramfs` and `firecracker_rootfs` wrap shell tools to create cpio.gz and ext4 images respectively, enforcing static linking for executables.
*   **MicroVM Launcher**: Generates a shell script from a template that resolves runfiles and invokes the Firecracker VMM with a generated `vm.json`.
*   **Test Infrastructure**: Wraps `sh_test` targets, injecting logic to monitor serial console output for expected/unexpected markers and handling timeouts. Cluster tests manage Linux bridges, TAP devices, and persistent disks across multiple concurrent VM instances.