<!-- docdaemon ts:2026-10-10T19:05:48Z hash:3a36ca085f9ddad5 model:openrouter/qwen/qwen3.7-flash -->
# tests/cluster

## TL;DR
This directory contains the test infrastructure and initialization scripts for validating multi-VM Firecracker scenarios, including networking, k3s clustering, IP renumbering, and disk installation.

## Overview
The `tests/cluster` directory orchestrates complex microVM interactions on a host bridge using `/dev/kvm`. It defines Bazel test suites that isolate each scenario in unique subnets to allow concurrent execution. The suite verifies critical cluster behaviors such as end-to-end connectivity, Kubernetes formation, persistent identity across IP changes, and OS installation from rootfs images.

## Deep Dive
### Test Orchestration
`BUILD.bazel` defines four distinct test scenarios: `nettest`, `k3s_cluster`, `renumber`, and `install_to_disk`. Each scenario configures specific VM resources (memory, vCPUs) and timeouts. Tests are tagged `manual` and `local`, requiring explicit invocation. The build system loads custom Firecracker macros to manage the lifecycle of these microVMs.

### Initialization Scripts
Each test scenario utilizes a specialized init script acting as PID 1 or `/sbin/init`:
*   **nettest_init.sh**: Validates basic network connectivity between two VMs by pinging a peer IP derived from kernel command-line arguments. It reports success via `NETOK` markers.
*   **renumber_init.sh**: Manages identity persistence during IP address changes. It distinguishes between new boots and recovery states using a persistent disk (`/dev/vdb`) to verify healing after renumbering.
*   **install_node_init.sh**: Verifies system integrity after an OS installation. It checks device mounts, validates the root partition, and confirms peer connectivity before signaling readiness.
*   **installer.sh**: Provisions block devices with GPT layouts (ESP and RootFS). It injects cluster configuration, including secrets, into the root filesystem image using `debugfs` before writing it to disk.

### Configuration Management
Static fixtures like `hostname.txt` provide deterministic hostnames for testing. Configuration parameters such as IPs and secrets are passed via kernel command lines or injected settings files, ensuring reproducible environments without relying on external state.

## Key Interfaces
*   `BUILD.bazel`: Defines the `:cluster` test suite and individual test targets.
*   `nettest_init.sh`: Entry point for network connectivity validation.
*   `renumber_init.sh`: Entry point for IP renumbering and identity persistence tests.
*   `install_node_init.sh`: Entry point for post-installation verification.
*   `installer.sh`: Script for provisioning disk images and injecting cluster settings.
*   `hostname.txt`: Static hostname fixture for deterministic testing.

## Dependencies
*   Bazel build system
*   Firecracker microVM runtime
*   KVM hypervisor support (`/dev/kvm`)
*   BusyBox utilities (for minimal environment setup)
*   k3s binaries (for cluster tests)
*   Linux kernel with CONFIG_IP_PNP

## Subcomponents
*   `BUILD.bazel`
*   `hostname.txt`
*   `install_node_init.sh`
*   `installer.sh`
*   `nettest_init.sh`
*   `renumber_init.sh`