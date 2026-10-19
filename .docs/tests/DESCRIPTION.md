<!-- docdaemon ts:2026-10-19T23:25:26Z hash:2bfa53477efadbdd model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains the comprehensive test infrastructure for validating Firecracker microVMs, including unit tests for build logic and integration tests for networking, clustering, and container execution.

## Overview
The `tests` directory ensures the correctness of the entire microVM lifecycle, from image construction to runtime behavior. It separates concerns into isolated subdirectories: `unit` for mocking-based validation of scripts and launchers, and specialized integration suites (`cluster`, `container`, `k3s`, `vm`) for end-to-end scenarios requiring actual KVM execution. This structure allows for fast feedback on build tools while rigorously verifying complex interactions like IP renumbering and Kubernetes formation.

## Deep Dive
### Unit Testing and Mocking
The `unit/` suite validates helper scripts and configuration generation without hardware dependencies. It uses `fake_firecracker.sh` to simulate VM invocations, capturing arguments and state dumps to verify launcher logic. Tests ensure that image builders (`mkrootfs`, `mkinitramfs`) produce correct ext4 structures with root-owned inodes (0:0), preventing host UID leakage during builds.

### Integration Scenarios
Integration tests run real microVMs to verify critical behaviors. The `cluster/` directory orchestrates multi-VM setups for network connectivity, k3s formation, and disk installation, using unique subnets for concurrent execution. `container/` tests OCI image layering, specifically AUFS whiteout handling and environment propagation. `k3s/` validates extra asset injection and manifest application, including negative tests for failure reporting. `vm/` covers basic boot sequences, storage persistence, and timeout detection via serial console assertions.

### Configuration and Fixtures
Tests rely on deterministic configurations passed via kernel command lines or injected settings files. Static fixtures like `hostname.txt` and payload files ensure reproducible environments. Recent changes enforced strict ownership checks on guest inodes to address build-user UID leakage issues discovered during CI runs.

## Key Interfaces
*   `BUILD.bazel`: Defines all test targets, including `sh_test`, `firecracker_microvm`, and custom rules.
*   `testlib.sh`: Shared shell utilities for assertions, ELF parsing, and ext4 inspection.
*   `fake_firecracker.sh`: Mock VMM script for simulating VM launches in unit tests.
*   `nettest_init.sh`: Guest entry point for network connectivity validation.
*   `renumber_init.sh`: Guest entry point for IP renumbering and identity persistence.
*   `install_node_init.sh`: Guest entry point for post-installation verification.
*   `installer.sh`: Script for provisioning disk images and injecting cluster settings.
*   `run.sh`: Entrypoint for container environment and filesystem verification.
*   `main.go`: Guest-side test binary for k3s extra asset validation.
*   `expect_failure.sh`: Wrapper for verifying negative test outcomes and timeouts.

## Dependencies
*   Bazel Build System
*   Firecracker MicroVM Runtime (pinned version)
*   KVM Hypervisor (`/dev/kvm`)
*   BusyBox Utilities
*   k3s Binaries
*   Linux Kernel (with CONFIG_IP_PNP and reboot support)
*   rules_oci (for container image construction)
*   jq (for JSON processing in tests)

## Subcomponents
*   `BUILD.bazel`
*   `cluster/`
*   `container/`
*   `k3s/`
*   `unit/`
*   `vm/`