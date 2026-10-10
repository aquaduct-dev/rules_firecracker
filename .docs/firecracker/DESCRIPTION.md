<!-- docdaemon ts:2026-10-10T19:07:04Z hash:07c370520eb151a2 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory provides the public Bazel targets and Starlark macros for building, testing, and managing Firecracker microVMs.

## Overview
The `firecracker` package serves as the primary entry point for consumers of `rules_firecracker`, exposing guest kernels, binaries, and root filesystem generation tools while hiding implementation details. It bridges Bazel's dependency management with runtime assets, ensuring reproducible and statically linked artifacts for isolated virtual machines. The module abstracts away VM lifecycle management, serial console monitoring, and complex integration testing scenarios like multi-node Kubernetes clusters.

## Deep Dive
### Public API and Macros
The `defs.bzl` file re-exports core rules from the private implementation, providing a consistent namespace for user workspaces. It exposes macros for creating initial RAM filesystems (`firecracker_initramfs`) and root filesystems (`firecracker_rootfs`). For virtual machine definitions, it offers `firecracker_microvm` for single instances and `firecracker_container` for container-based VMs. Testing capabilities include basic microVM tests, K3s-specific tests, cluster tests, and renumbering scenarios.

### Binary and Kernel Assets
The build system explicitly constructs and exposes static binaries required for testing and image creation. A Linux 6.1.155 kernel (`vmlinux`) is built from source using a pinned configuration and toolchain, cached for performance but not marked local. Platform-agnostic access to the Firecracker binary is provided via an alias that resolves to x86_64 or aarch64 specific repositories based on the host CPU. Additional pinned upstream binaries such as `busybox_static`, `k3s_binary`, and `jq` are made executable for use in test scripts and rootfs construction.

### Root Filesystem Generation
Shell scripts exposed by the public API automate the creation of bootable disk images. These tools validate ELF binaries to ensure static linking, assemble directory trees, and format ext4 or cpio+gzip archives. Specialized variants handle specific use cases, including minimal Kubernetes environments and full Debian-based systems for edge nodes. All implementation scripts, templates, and private macros remain under `private/` and are excluded from the public API.

## Key Interfaces
- `//firecracker:defs.bzl`: Public Starlark macros for defining microVMs, containers, and tests.
- `@rules_firecracker//:firecracker`: Alias for the platform-specific Firecracker binary.
- `@rules_firecracker//:vmlinux`: Pinned Linux 6.1.155 kernel binary.
- `mkrootfs.sh`: Script for generating generic ext4 root filesystem images.
- `mkk3srootfs.sh`: Script for generating minimal Kubernetes (K3s) root filesystems.
- `DEFAULT_KERNEL_CMDLINE`: Constant string providing default kernel command-line arguments.

## Dependencies
- `@rules_shell//shell:rules_bzl`: Provides shell-related rules used by macros.
- Host toolchain: Required for kernel compilation and image formatting utilities.
- Docker/Podman: Used by internal node image builders for base image construction.
- Upstream binaries: Pinned versions of busybox, k3s, and jq.

## Subcomponents
- `BUILD.bazel`: Public target definitions and visibility settings.
- `defs.bzl`: Public API entry point for Starlark macros.
- `private/`: Internal implementation details, macros, and scripts.