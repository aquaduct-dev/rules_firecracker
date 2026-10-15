<!-- docdaemon ts:2026-10-15T22:44:22Z hash:06f3e61c30a3d758 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains the private build macros, test infrastructure scripts, and root filesystem generators for the Firecracker rules.

## Overview
The `firecracker/private` package implements the internal machinery required to build, configure, and test microVMs using Bazel. It bridges high-level Starlark macros with low-level shell scripts that handle kernel compilation, disk image creation, and VM orchestration. This separation allows public rules to remain simple while encapsulating complex build logic and testing harnesses internally.

## Deep Dive
### Build Macros and Visibility
The `macros.bzl` file defines internal Starlark rules such as `firecracker_microvm`, `firecracker_test`, and `firecracker_k3s_test`. These macros generate `genrule`s that invoke shell scripts to assemble VM configurations, create disk images, and execute tests. The `BUILD.bazel` file restricts visibility of the macro library to the local package, ensuring that only authorized callers can instantiate these internal targets.

### Root Filesystem Generation
Several scripts automate the creation of bootable disk images tailored for specific use cases. `mkrootfs.sh` provides a generic ext4 builder, while specialized variants like `mkk3srootfs.sh`, `mkcontainerfs.sh`, and `mkinitramfs.sh` handle Kubernetes clusters, OCI containers, and minimal initramfs respectively. These tools ensure all binaries are statically linked and validate ELF headers to prevent runtime failures in the isolated guest environment.

### Test Orchestration
The directory includes sophisticated test runners for integration scenarios. `cluster_run.sh` manages multi-VM networking by creating bridges and TAP devices, enabling concurrent microVM execution. Scripts like `gen_test.sh` and `gen_k3s_test.sh` generate self-contained Bash wrappers that monitor serial output, enforce timeouts, and parse JSON reports for validation. This infrastructure supports both single-node smoke tests and complex k3s cluster formation tests.

### Kernel Compilation
`build_kernel.sh` automates the compilation of a pinned Linux kernel source tarball into an uncompressed vmlinux ELF image. It ensures reproducibility by disabling unnecessary features like module loading and applying a specific configuration, producing a binary optimized for Firecracker’s microVM requirements.

## Key Interfaces
- `//firecracker/private:defs.bzl`: Publicly visible exports for helper scripts and templates.
- `//firecracker/private:macros`: Internal Starlark library for VM and test rule definitions.
- `build_kernel.sh`: Script to compile a deterministic vmlinux kernel image.
- `cluster_run.sh`: Orchestrator for multi-VM network setup and concurrent testing.
- `mkrootfs.sh`: Generic ext4 root filesystem generator.
- `k3s_init.sh` / `k3s_cluster_init.sh`: Guest-side init processes for single-node and cluster k3s tests.

## Dependencies
- `@rules_shell//shell:rules_bzl`: Provides shell-related rules used by macros.
- Host toolchain: Required for `build_kernel.sh` to compile the Linux kernel.
- Docker/Podman: Used by `mknodeimage.sh` and `mksystemdrootfs.sh` to build base Debian filesystems.
- `fakeroot`: Utilized during ext4 image formatting to manage file ownership without actual root privileges.

## Subcomponents
- `BUILD.bazel`: Build configuration and visibility settings.
- `macros.bzl`: Internal Starlark macro definitions.
- `build_kernel.sh`: Kernel compilation script.
- `cluster_run.sh`: Multi-VM network orchestrator.
- `gen_k3s_test.sh`: K3s test wrapper generator.
- `gen_test.sh`: General test wrapper generator.
- `k3s_cluster_init.sh`: Cluster node init process.
- `k3s_init.sh`: Single-node k3s init process.
- `mkcontainerfs.sh`: OCI to ext4 converter.
- `mkinitramfs.sh`: Initramfs image generator.
- `mkk3srootfs.sh`: k3s rootfs builder.
- `mknodeimage.sh`: Openfactoryd node image builder.
- `mknoderootfs.sh`: Production node rootfs builder.
- `mkrootfs.sh`: Generic ext4 builder.
- `mksystemdrootfs.sh`: Systemd-based rootfs builder.