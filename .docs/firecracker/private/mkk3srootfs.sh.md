<!-- docdaemon ts:2026-10-19T23:24:33Z hash:49bf8808ca2029c7 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds a static ext4 rootfs image containing k3s, busybox, and a test binary for execution inside a Firecracker microVM.

It validates that input binaries (busybox, k3s, test binary) are statically linked ELF executables to ensure they run without external dependencies in the minimal guest environment. The script creates a staging directory, populating it with symlinks for busybox applets, the k3s binary (with aliases like `kubectl`), and configuration files (`fstab`, `hosts`, etc.). It accepts repeatable arguments to inject additional files, executables, Kubernetes manifests, or OCI images into specific directories within the rootfs.

After assembling the tree, it formats an ext4 image using `mkfs.ext4 -d`. Since `mkfs.ext4` preserves file ownership from the build host (often non-root), the script uses `debugfs` to recursively re-own all inodes to `root:root` (0:0), ensuring correct permissions for the guest OS. The final output is a self-contained disk image ready for VM launch.