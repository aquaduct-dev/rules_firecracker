<!-- docdaemon ts:2026-10-30T02:13:18Z hash:817cfbda4dba227a model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains the complete test infrastructure for validating Firecracker microVMs, ranging from isolated unit tests to complex multi-VM Kubernetes cluster scenarios.

## Overview
The `tests` suite ensures correctness across the entire build and runtime stack by verifying image construction, launcher behavior, and guest-side logic. It employs a hybrid approach: shell-based unit tests mock the VMM to validate configuration generation without hardware, while integration tests spin up real microVMs using KVM to verify boot sequences, networking, and storage integrity. The suite also covers advanced features like OCI image layering, IP renumbering persistence, and full k3s cluster formation with netfilter validation.

## Deep Dive
### Unit Testing and Mocking
The `unit/` subdirectory isolates helper scripts and image builders (`mkrootfs`, `mkinitramfs`) from the hypervisor. By mocking the Firecracker binary via `fake_firecracker.sh`, these tests verify CPU/memory settings, network interface configurations, and ext4 inode ownership (enforced as root-owned to prevent UID leakage). They also validate the test generation utilities that produce guest-side init scripts, ensuring marker detection and timeout handling are robust against malformed JSON or missing states.

### Integration and VM Validation
The `vm/` and `container/` directories execute real microVMs to verify boot sequences and filesystem semantics. `vm/` checks initrd/rootfs initialization, block device persistence on extra drives, and failure modes like timeouts. `container/` focuses on OCI image mechanics, specifically AUFS whiteout file handling across layers, ensuring that deleted files in lower layers are correctly masked in the overlay. These tests assert serial console output against expected markers to confirm successful environment propagation and runtime state.

### Cluster and Network Scenarios
Complex interactions are validated in `cluster/` and `k3s/`. The `cluster/` suite orchestrates multi-VM setups on host bridges to test end-to-end connectivity, IP renumbering identity persistence, and OS installation from rootfs images. The `k3s/` directory validates Kubernetes functionality within guests, including kube-proxy netfilter support for ClusterIP routing, containerd auto-import of local images, and ConfigMap injection. Negative testing in `k3s/failing/` ensures the harness correctly reports intentional failures rather than masking them as silent passes.

## Key Interfaces
*   `BUILD.bazel`: Defines all Bazel test targets, including `sh_test`, `firecracker_microvm`, and custom macros.
*   `testlib.sh`: Shared shell utilities for assertions, ELF parsing, and ext4 inspection in unit tests.
*   `fake_firecracker.sh`: Mock VMM script that captures invocation arguments and simulates resource resolution.
*   `nettest_init.sh`: Guest entry point for basic two-VM network connectivity validation.
*   `renumber_init.sh`: Guest entry point for verifying identity persistence during IP address changes.
*   `installer.sh`: Script for provisioning GPT disk layouts and injecting cluster secrets into rootfs images.
*   `main.go`: Guest-side Go binary for k3s feature validation, flag checking, and network verification.
*   `oci_image`: Bazel target defining the multi-layer OCI container structure for container tests.

## Dependencies
*   Bazel Build System
*   Firecracker MicroVM Runtime (pinned version)
*   KVM Hypervisor Support (`/dev/kvm`)
*   BusyBox Utilities (minimal userspace)
*   k3s and containerd Binaries (for cluster tests)
*   Linux Kernel (with CONFIG_IP_PNP, netfilter modules, and reboot support)
*   rules_oci (for constructing test container images)
*   jq (JSON processing for test generation validation)

## Subcomponents
*   `BUILD.bazel`
*   `cluster/`
*   `container/`
*   `k3s/`
*   `unit/`
*   `vm/`