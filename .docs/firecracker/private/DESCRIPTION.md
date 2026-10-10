<!-- docdaemon ts:2026-10-10T19:05:48Z hash:e926c424abeb2d1d model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains the private build macros, test infrastructure scripts, and root filesystem generators for the Firecracker rules.

## Overview
The `firecracker/private` package provides the internal implementation details for `rules_firecracker`, exposing helper scripts and templates to caller packages while keeping core macro logic encapsulated. It bridges Bazel's dependency management with actual runtime assets, including kernel compilation, microVM launching, and complex integration testing scenarios like multi-node k3s clusters. The directory ensures that all generated artifacts—such as ext4 rootfs images and initramfs archives—are reproducible and statically linked for reliable execution within isolated virtual machines.

## Deep Dive
### Build Macros and Visibility
The `BUILD.bazel` file restricts the `macros` library to the local package, ensuring controlled access to the core logic defined in `macros.bzl`. This file exposes shell scripts, templates, and configuration files via `exports_files`, making them available for `genrule`s in consumer packages. The macros define public-facing rules like `firecracker_microvm` and `firecracker_test`, which abstract away the complexity of VM lifecycle management, serial console monitoring, and timeout handling.

### Root Filesystem Generation
A suite of scripts (`mkrootfs.sh`, `mkinitramfs.sh`, `mkcontainerfs.sh`, etc.) automates the creation of bootable disk images. These tools validate ELF binaries to ensure static linking, assemble directory trees, and format ext4 or cpio+gzip archives. Specialized variants handle specific use cases: `mkk3srootfs.sh` prepares minimal Kubernetes environments, while `mknodeimage.sh` and `mknoderootfs.sh` build full Debian-based systems for edge nodes and production hardware.

### Test Infrastructure and Orchestration
Scripts like `cluster_run.sh` and `gen_k3s_test.sh` manage complex integration tests. `cluster_run.sh` orchestrates shared network bridges and TAP devices for concurrent multi-VM testing, while `gen_test.sh` generates self-contained smoke tests that monitor serial output for early exit conditions. Guest-side initializers (`k3s_init.sh`, `k3s_cluster_init.sh`) act as PID 1 processes, handling cluster formation, readiness checks, and structured JSON reporting to the host orchestrator.

## Key Interfaces
- `//firecracker/private:defs.bzl`: Public macros for defining microVMs, containers, and tests.
- `//firecracker/private:macros`: Internal Bazel library implementing rule logic.
- `build_kernel.sh`: Generates deterministic vmlinux ELF images from pinned sources.
- `cluster_run.sh`: Orchestrates multi-VM networking and launch for integration tests.
- `mkrootfs.sh` / `mkinitramfs.sh`: Generators for ext4 and cpio root filesystems.

## Dependencies
- `@rules_shell//shell:rules_bzl`: Provides shell-related rules used by macros.
- Host toolchain: Required for `build_kernel.sh` and image formatting utilities.
- Docker/Podman: Used by `mknodeimage.sh` and `mksystemdrootfs.sh` for base image construction.

## Subcomponents
- `BUILD.bazel`: Build configuration and visibility settings.
- `macros.bzl`: Core Bazel macro definitions.
- `build_kernel.sh`: Kernel compilation script.
- `cluster_run.sh`: Multi-VM network orchestration.
- `gen_k3s_test.sh`: K3s test wrapper generator.
- `gen_test.sh`: Smoke test generator.
- `k3s_cluster_init.sh`: Multi-node k3s init process.
- `k3s_init.sh`: Single-node k3s init process.
- `mkcontainerfs.sh`: OCI to ext4 converter.
- `mkinitramfs.sh`: Initramfs archive generator.
- `mkk3srootfs.sh`: Minimal k3s rootfs builder.
- `mknodeimage.sh`: Debian node image builder.
- `mknoderootfs.sh`: Production rootfs builder.
- `mkrootfs.sh`: Generic ext4 image builder.
- `mksystemdrootfs.sh`: Systemd-based rootfs builder.