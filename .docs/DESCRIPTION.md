<!-- docdaemon ts:2026-10-09T22:29:28Z hash:88b6f2ab998a0b9c model:openrouter/qwen/qwen3.7-flash -->
# Firecracker MicroVM Build & Test Infrastructure

## TL;DR
This directory provides Bazel rules, shell scripts, and guest-side agents to build Linux kernels, generate root filesystems, and execute integration tests for Firecracker microVMs, including single-node k3s clusters and multi-VM networking scenarios.

## Overview
The project automates the creation of reproducible, hermetic builds for Firecracker-based virtual machines. It handles the entire lifecycle from kernel compilation and rootfs generation to test orchestration and result reporting. By leveraging Bazel's sandboxing and dependency management, it ensures that tests run consistently across different environments while adhering to strict security and performance constraints.

## Deep Dive
### Build System Integration
The core logic resides in `BUILD.bazel` and `MODULE.bazel`, which define targets for compiling a pinned Linux 6.1 kernel (`vmlinux`) and packaging static binaries like BusyBox and k3s. The `defs.bzl` file exposes public macros such as `firecracker_k3s_test` and `firecracker_cluster_test`, allowing developers to declare complex VM setups as simple Bazel rules. These rules manage resource dependencies, ensuring that all artifacts are built before test execution begins.

### Rootfs Generation
A suite of shell scripts (`mkrootfs.sh`, `mkinitramfs.sh`, `mkk3srootfs.sh`, etc.) constructs various filesystem images. `mkrootfs.sh` creates generic ext4 images, while specialized scripts handle k3s clusters, systemd-based nodes, and OCI container conversions. These tools ensure that all binaries within the guest are statically linked, preventing runtime dependency failures in minimal environments. They also inject necessary configuration files, init scripts, and test binaries into the staging directories before formatting.

### Test Orchestration
Testing infrastructure is split between host-side orchestrators and guest-side agents. Scripts like `cluster_run.sh` manage network bridges and TAP devices to enable multi-VM communication without requiring elevated privileges inside the guest. Test generators (`gen_test.sh`, `gen_k3s_test.sh`) produce self-contained shell scripts that boot VMs, stream logs, and parse structured JSON reports for pass/fail determination. Guest agents, such as those in `k3s_smoke/`, perform specific validation tasks like checking node readiness or verifying network connectivity.

## Key Interfaces
*   `firecracker_initramfs`: Macro to build compressed cpio+gzip initramfs images.
*   `firecracker_rootfs`: Macro to build ext4 disk images from staging directories.
*   `firecracker_microvm`: Macro to wrap rootfs and kernel into a runnable binary target.
*   `firecracker_test`: Macro to assert serial console output against expected markers.
*   `firecracker_k3s_test`: Macro to provision and test single-node Kubernetes clusters.
*   `firecracker_cluster_test`: Macro to orchestrate multi-VM networking scenarios.
*   `build_kernel.sh`: Script to compile Linux kernel source into an uncompressed ELF.
*   `cluster_run.sh`: Orchestrator for multi-VM lifecycle and network setup.

## Dependencies
*   Bazel (with `rules_go` and `rules_python` extensions)
*   Linux Kernel 6.1.155 source code
*   Static BusyBox binary
*   Static k3s binary
*   Host tools: `make`, `gcc`, `qemu-img`, `mkfs.ext4`, `jq`
*   KVM support on the host machine

## Subcomponents
*   `BUILD.bazel`: Main build targets and test definitions.
*   `MODULE.bazel`: External dependency declarations.
*   `defs.bzl`: Public Bazel macros and rules.
*   `k3s_smoke/`: Go-based smoke test agent for k3s health checks.
*   `build_kernel.sh`: Kernel compilation script.
*   `cluster_run.sh`: Multi-VM network and lifecycle orchestrator.
*   `gen_test.sh`: Generic microVM test script generator.
*   `gen_k3s_test.sh`: K3s-specific test script generator.
*   `mkrootfs.sh`: Generic ext4 rootfs builder.
*   `mkinitramfs.sh`: Initramfs image generator.
*   `mkk3srootfs.sh`: k3s cluster rootfs builder.
*   `mkcontainerfs.sh`: OCI image to ext4 converter.
*   `mknodeimage.sh`: Debian node image builder for hardware.
*   `mknoderootfs.sh`: Production node rootfs builder.
*   `mksystemdrootfs.sh`: systemd-based rootfs builder.
*   `nettest_init.sh`: Networking test entry point.
*   `k3s_init.sh`: Single-node k3s init process.
*   `k3s_cluster_init.sh`: Multi-node k3s init process.