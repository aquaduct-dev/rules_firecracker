<!-- docdaemon ts:2026-10-30T02:12:50Z hash:5a1fef2eaf04e9fe model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines the public Bazel targets for the Firecracker rules, exposing guest kernels, binaries, and rootfs generation tools.

### Public API
The `exports_files` directive exposes `defs.bzl`, which contains the high-level macros (`firecracker_k3s_test`, etc.). The implementation details are private.

**Core Binaries & Artifacts**
*   **`vmlinux`**: Builds the guest kernel (Linux 6.1.155) from source using a pinned config. It enables netfilter modules required by kube-proxy for ClusterIP Services in k3s guests. Built with the HOST toolchain and cached.
*   **`firecracker`**: An alias resolving to the pinned upstream release binary for the current CPU architecture (x86_64 or aarch64). Runners resolve this via runfiles, not the host PATH.
*   **`busybox_static`**, **`k3s_binary`**, **`jq`**: Pinned static binaries for testing and rootfs construction. Executable bits are set during build since upstream sources lack them.

**Rootfs Generators**
A list comprehension generates `sh_binary` targets for image builders:
*   `mkinitramfs`, `mkrootfs`, `mkcontainerfs`: Standard rootfs creation.
*   `mkk3srootfs`: Generates a rootfs for k3s tests.
*   `mksystemdrootfs`, `mknoderootfs`, `mknodeimage`: Debian-based systemd images for production nodes.
*   `gen_test`, `gen_k3s_test`: Test script generators.

**Initialization Scripts**
*   **`k3s_init`**, **`k3s_cluster_init`**: Aliases to private shell scripts used as PID-1 init processes for firecracker VMs.