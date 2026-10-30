<!-- docdaemon ts:2026-10-30T02:13:15Z hash:2320b82a192e06ad model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory provides Bazel rules and build infrastructure for compiling guest kernels, constructing root filesystems, and orchestrating Firecracker microVMs.

## Overview
The `firecracker` package bridges Bazel’s dependency management with the runtime requirements of lightweight virtual machines. It exposes public macros for building bootable disk images, launching single or clustered VMs, and running integration tests against k3s environments. By abstracting away low-level disk formatting and kernel configuration, it allows consumers to define VM behaviors declaratively.

## Deep Dive
### Filesystem Construction
Root filesystems are assembled into ext4 images using scripts like `mkrootfs.sh` and `mkk3srootfs.sh`. These tools use `mkfs.ext4 -d` to pack staging trees but subsequently run `debugfs` to recursively re-own all inodes to `root:root` (0:0). This step is critical because `mkfs.ext4` preserves host file ownership, which would otherwise cause permission errors in the unprivileged guest kernel. Similarly, `mkinitramfs.sh` creates gzip-compressed cpio archives, ensuring all binaries are statically linked to avoid dynamic loader dependencies.

### Kernel Compilation
The `vmlinux` target automates the compilation of a pinned Linux kernel source tarball into an uncompressed ELF binary. The build applies a specific `.config` that disables unnecessary features like module loading and sets deterministic timestamps for reproducible outputs. Recent updates enabled netfilter modules required by kube-proxy, ensuring ClusterIP Services function correctly in k3s guests.

### Test Orchestration
Test infrastructure includes generators (`gen_test.sh`, `gen_k3s_test.sh`) that produce self-contained shell scripts for Bazel `sh_test` targets. These scripts manage VM lifecycle, stream serial logs, and handle early-exit logic based on console markers. For multi-node scenarios, `cluster_run.sh` manages network bridges and TAP devices, while specialized init processes bootstrap Kubernetes clusters and validate readiness.

## Key Interfaces
*   `//firecracker:defs.bzl`: Public API entry point exposing high-level macros.
*   `firecracker_microvm`: Macro to launch a single microVM instance.
*   `firecracker_rootfs` / `firecracker_initramfs`: Rules to generate ext4 and cpio disk images.
*   `firecracker_k3s_test`: Rule for integrating k3s cluster validation within Bazel tests.
*   `DEFAULT_KERNEL_CMDLINE`: Standard kernel command line configuration constant.

## Dependencies
*   `@rules_shell//shell:rules_bzl`: Shell-related rules used by macros.
*   Pinned Firecracker release binaries (via `MODULE.bazel`).
*   Standard Linux utilities: `mkfs.ext4`, `debugfs`, `busybox`, `jq`.

## Subcomponents
*   `private/`: Internal build macros, shell utilities, and test infrastructure.
*   `BUILD.bazel`: Public Bazel targets for kernels, binaries, and rootfs tools.
*   `defs.bzl`: Public API entry point for Firecracker Bazel rules.