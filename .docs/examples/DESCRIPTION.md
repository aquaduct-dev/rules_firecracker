<!-- docdaemon ts:2026-10-19T23:25:24Z hash:57d2e0a40a52d842 model:openrouter/qwen/qwen3.7-flash -->
# examples

## TL;DR
This directory provides minimal, self-contained examples demonstrating how to build and test Firecracker microVMs using both initramfs and ext4 rootfs configurations.

## Overview
The `examples` directory serves as a foundational reference for integrating `rules_firecracker` into a Bazel workspace. It illustrates the complete lifecycle of creating lightweight virtual machines, from assembling static assets and initialization scripts to defining build targets and executing integration tests. By showcasing two distinct root filesystem strategies—initramfs and ext4—it helps developers understand how to configure kernel command lines, manage mounts, and verify VM output in automated CI pipelines.

## Deep Dive
### Build Configuration
The `hello/BUILD.bazel` file defines four primary targets: `hello_initrd`, `hello_vm`, `hello_test`, and their ext4 counterparts (`hello_rootfs`, `hello_rootfs_vm`, `hello_rootfs_test`). The initramfs target packages `greeting.txt` and `hello_init.sh` into a compressed archive, while the ext4 target constructs a read-write filesystem image using BusyBox binaries. These targets leverage `firecracker_initramfs`, `firecracker_rootfs`, and `firecracker_microvm` rules to handle image creation and VM instantiation.

### Initialization Scripts
Both `hello/hello_init.sh` and `hello/hello_rootfs_init.sh` act as PID 1 entry points. They perform essential housekeeping, such as mounting the `/proc` filesystem to ensure standard Linux utilities function correctly. After verifying environment accessibility, they print specific markers (`HELLO_FROM_INITRD` or `HELLO_FROM_ROOTFS`) to stdout. Finally, they execute a forced reboot (`reboot -f`), which terminates the VM session cleanly due to the `reboot=k` kernel argument, allowing the test harness to detect successful boot completion.

### Testing Workflow
Tests are defined using the `firecracker_test` rule, which boots the respective VM and captures its serial output. The test logic verifies that expected markers appear in the log and ensures no kernel panics occur. This setup validates that the VM can start, access necessary resources, and exit gracefully, providing a robust smoke test for the Firecracker integration.

### k3s Smoke Test Suite
The `k3s_smoke` directory implements a static Go binary and associated Bazel targets to verify k3s cluster readiness inside a Firecracker microVM. The guest binary runs after `k3s` initializes, checking for the existence of `/etc/rancher/k3s/k3s.yaml` and polling `kubectl get nodes` until a node reports `Ready=True`. Static linking is mandatory because the embedded rootfs contains only busybox and k3s, lacking a C library. Unit tests isolate parsing logic using `strings.Cut` to handle tab-separated node status output efficiently.

## Key Interfaces
- `//examples/hello:hello_vm` - MicroVM target using initramfs with 128 MiB memory.
- `//examples/hello:hello_rootfs_vm` - MicroVM target using ext4 rootfs with read-write mount.
- `//examples/hello:hello_test` - Test target verifying initramfs boot markers.
- `//examples/hello:hello_rootfs_test` - Test target verifying ext4 boot markers.
- `waitNodeReady` - Polls kubectl until timeout, distinguishing API failures from unready states.
- `hasReady` - Parses tab-separated node output to detect any node with status `True`.
- `writeReport` - Serializes diagnostic data to JSON for host-side analysis.

## Dependencies
- `//firecracker:defs.bzl` - Core definitions for Firecracker rules and default kernel cmdline.
- `busybox` - Used in the ext4 rootfs for basic utilities and the init script.
- `rules_go` - For Go compilation and static linking.
- `firecracker` - Pinned v1.17.0 binaries for microVM orchestration.
- `k3s` - Embedded in the guest rootfs.

## Subcomponents
- `hello/` - Minimal VM examples with initramfs and ext4 support.
- `k3s_smoke/` - Kubernetes cluster readiness verification suite.