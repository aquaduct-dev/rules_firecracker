<!-- docdaemon ts:2026-10-19T23:25:25Z hash:7dfe5c387ead6546 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory provides Bazel rules and macros for building, configuring, and testing Firecracker microVMs.

## Overview
The `firecracker` module exposes a public API for constructing bootable disk images and launching lightweight virtual machines within the Bazel build system. It abstracts away the complexity of kernel compilation, root filesystem generation, and VM orchestration, allowing consumers to define declarative VM configurations. The implementation is split between public entry points in the root directory and internal macros and scripts in the `private/` subdirectory.

## Deep Dive
### Image Building
Disk images are constructed using shell scripts that assemble ext4 or cpio archives from staging trees. A critical step involves re-owning all inodes to `root:root` (0:0) after formatting to prevent permission errors in the unprivileged guest kernel. This ensures that files copied via tools like `mkfs.ext4 -d` do not retain host user ownership. Initramfs archives are validated to ensure all binaries are statically linked, avoiding dynamic loader dependencies.

### Kernel Compilation
A pinned Linux kernel source tarball is compiled into an uncompressed ELF binary. The build process applies a specific configuration that disables unnecessary features such as module loading. Deterministic build timestamps are enforced to guarantee reproducible outputs suitable for consistent microVM booting.

### Test Orchestration
Test infrastructure includes generators that produce self-contained shell scripts for Bazel `sh_test` targets. These scripts manage VM lifecycle, stream serial logs, and implement early-exit logic based on console markers. For multi-node scenarios, orchestrators handle network bridges and TAP devices, while init processes bootstrap Kubernetes clusters and validate readiness.

## Key Interfaces
- `firecracker_initramfs`: Rule to construct bootable initramfs images.
- `firecracker_rootfs`: Rule to generate ext4 root filesystem images.
- `firecracker_microvm`: Macro to create and run a single microVM instance.
- `firecracker_container`: Rule for handling OCI image-based VMs.
- `firecracker_test`: Runs tests against a single VM.
- `firecracker_k3s_test`: Tests against a k3s cluster within a VM.
- `DEFAULT_KERNEL_CMDLINE`: Standard kernel command line configuration.

## Dependencies
- `@rules_shell//shell:rules_bzl`: Shell-related rules used by macros.
- Pinned Firecracker release binaries (via `MODULE.bazel`).
- Standard Linux utilities: `mkfs.ext4`, `debugfs`, `busybox`, `jq`.

## Subcomponents
- `BUILD.bazel`: Public target definitions and aliases.
- `defs.bzl`: Public API entry point and macro exports.
- `private/macros.bzl`: Internal Starlark macro definitions.
- `private/BUILD.bazel`: Build configuration and visibility.
- `private/build_kernel.sh`: Kernel compilation script.
- `private/mkrootfs.sh`: Generic ext4 rootfs builder.
- `private/mkk3srootfs.sh`: k3s rootfs builder.
- `private/mkcontainerfs.sh`: OCI to ext4 conversion.
- `private/mkinitramfs.sh`: Initramfs archive assembly.
- `private/gen_test.sh`: Smoke-test script generator.
- `private/gen_k3s_test.sh`: K3s integration test generator.
- `private/cluster_run.sh`: Multi-VM network orchestrator.
- `private/k3s_init.sh`: Single-node k3s init process.
- `private/k3s_cluster_init.sh`: Multi-node k3s cluster init.