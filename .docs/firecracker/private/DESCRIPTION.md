<!-- docdaemon ts:2026-10-19T23:25:06Z hash:140dbec159d6cae8 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains the internal build macros, shell utilities, and test infrastructure required to compile kernels, construct root filesystems, and orchestrate Firecracker microVMs.

## Overview
The `firecracker/private` package bridges Bazel’s dependency management with the specific runtime requirements of Firecracker microVMs. It provides Starlark macros that abstract away the complexity of disk image creation, VM launching, and integration testing, allowing higher-level packages to define VM configurations declaratively. The directory also houses scripts for building static root filesystems from OCI images or Debian bases, ensuring guest environments are self-contained and permission-correct.

## Deep Dive
### Filesystem Construction
Several scripts (`mkrootfs.sh`, `mkk3srootfs.sh`, `mkcontainerfs.sh`) assemble ext4 images from staging trees. A critical implementation detail is the ownership fix: since `mkfs.ext4 -d` preserves host file ownership, these scripts use `debugfs` to recursively re-own all inodes to `root:root` (0:0). This ensures the unprivileged guest kernel does not encounter permission errors. Similarly, `mkinitramfs.sh` creates gzip-compressed cpio archives, validating that all binaries are statically linked to avoid dynamic loader dependencies.

### Kernel Compilation
`build_kernel.sh` automates the compilation of a pinned Linux kernel source tarball into an uncompressed `vmlinux` ELF binary. It applies a specific `.config`, disables unnecessary features like module loading, and sets deterministic build timestamps to ensure reproducible outputs suitable for microVM booting.

### Test Orchestration
The directory includes generators (`gen_test.sh`, `gen_k3s_test.sh`) that produce self-contained shell scripts for Bazel `sh_test` targets. These generated tests handle VM lifecycle management, serial log streaming, and early-exit logic based on console markers. For multi-node scenarios, `cluster_run.sh` manages network bridges and TAP devices, while `k3s_init.sh` and `k3s_cluster_init.sh` serve as PID 1 init processes inside guests to bootstrap Kubernetes clusters and validate readiness.

## Key Interfaces
- `//firecracker/private:defs.bzl`: Exports public visibility for assets and the internal macro library.
- `firecracker_microvm`: Macro to launch a single microVM instance.
- `firecracker_rootfs` / `firecracker_initramfs`: Rules to generate ext4 and cpio disk images.
- `firecracker_k3s_test`: Rule for integrating k3s cluster validation within Bazel tests.

## Dependencies
- `@rules_shell//shell:rules_bzl`: Provides shell-related rules used by the macros.
- Pinned Firecracker release binaries (via `MODULE.bazel`).
- Standard Linux utilities: `mkfs.ext4`, `debugfs`, `busybox`, `jq`.

## Subcomponents
- `macros.bzl`: Internal Starlark macro definitions.
- `BUILD.bazel`: Build configuration and visibility exports.
- `build_kernel.sh`: Kernel compilation script.
- `cluster_run.sh`: Multi-VM network and launch orchestrator.
- `gen_test.sh`: Smoke-test script generator.
- `gen_k3s_test.sh`: K3s integration test generator.
- `k3s_init.sh`: Single-node k3s init process.
- `k3s_cluster_init.sh`: Multi-node k3s cluster init process.
- `mkcontainerfs.sh`: OCI to ext4 conversion.
- `mkinitramfs.sh`: Initramfs archive assembly.
- `mkk3srootfs.sh`: k3s rootfs builder.
- `mknodeimage.sh`: Openfactoryd node image builder.
- `mknoderootfs.sh`: Production node rootfs builder.
- `mkrootfs.sh`: Generic ext4 rootfs builder.
- `mksystemdrootfs.sh`: Minimal systemd-based rootfs builder.