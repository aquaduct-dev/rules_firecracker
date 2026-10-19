<!-- docdaemon ts:2026-10-15T22:44:56Z hash:a9105e50fd2c65e0 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory provides the public Bazel rules and macros for building, configuring, and testing Firecracker microVMs.

## Overview
The `firecracker` package serves as the primary entry point for consumers of `rules_firecracker`, exposing guest kernels, binaries, and rootfs generation tools while hiding implementation details. It bridges high-level Starlark macros with low-level shell scripts to handle kernel compilation, disk image creation, and VM orchestration. This separation allows public rules to remain simple while encapsulating complex build logic internally.

## Deep Dive
### Build Macros and Visibility
The module exposes key rule types categorized by function: image building (`firecracker_initramfs`, `firecracker_rootfs`), VM execution (`firecracker_microvm`, `firecracker_container`), and testing suites (`firecracker_test`, `firecracker_k3s_test`). These macros are re-exported from `private/macros.bzl` to hide implementation complexity. The `bzl_library` target exposes `defs.bzl`, which contains the high-level macros driving the build system. Platform-agnostic access to the Firecracker binary is provided via an alias that resolves based on the current CPU platform.

### Root Filesystem Generation
Shell scripts automate the creation of bootable disk images tailored for specific use cases. Tools like `mkrootfs.sh` provide generic ext4 builders, while specialized variants handle Kubernetes clusters, OCI containers, and minimal initramfs. These tools ensure all binaries are statically linked and validate ELF headers to prevent runtime failures in the isolated guest environment. Initialization scripts such as `k3s_init` support guest-side setup for single-node and cluster tests.

### Kernel Compilation and Testing
A pinned Linux 6.1.155 kernel (`vmlinux`) is built from source using a specific configuration and toolchain, cached for performance but not marked local. Test infrastructure includes sophisticated runners for integration scenarios, managing multi-VM networking via bridges and TAP devices. Scripts generate self-contained Bash wrappers that monitor serial output, enforce timeouts, and parse JSON reports for validation, supporting both smoke tests and complex cluster formation scenarios.

## Key Interfaces
- `//firecracker:defs.bzl`: Public API entry point for loading Firecracker rules.
- `firecracker_microvm`: Rule for creating runnable microVM instances.
- `firecracker_test`: Rule for running tests against a single VM.
- `firecracker_k3s_test`: Rule for testing k3s clusters within a VM.
- `firecracker_initramfs` / `firecracker_rootfs`: Build a gzipped cpio initramfs or an ext4 rootfs image.
- `firecracker_container`: Boot an OCI image (flattened to ext4) as a microVM.
- `firecracker_cluster_test`: Boot several microVMs on a host bridge and wait for a marker.
- `firecracker_renumber_test`: Boot a cluster, then reboot it onto a new subnet with its persistent disks.
- `firecracker_install_cluster_test`: Run an installer onto each node's disk, then boot every node from its installed disk.
- `DEFAULT_KERNEL_CMDLINE`: Standard kernel command line configuration constant.
- `firecracker`: Alias for the platform-specific Firecracker binary.

## Dependencies
- Host toolchain: Required for compiling the Linux kernel.
- Docker/Podman: Used for building base Debian filesystems.
- `fakeroot`: Utilized during ext4 image formatting.
- `@rules_shell//shell:rules_bzl`: Provides shell-related rules.

## Subcomponents
- `BUILD.bazel`: Public Bazel targets and visibility settings.
- `defs.bzl`: Public API exports for macros and constants.
- `private/`: Internal build macros, test scripts, and generators.