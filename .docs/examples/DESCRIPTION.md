<!-- docdaemon ts:2026-10-10T19:07:05Z hash:3e8b5c883a873e7d model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains minimal, self-contained examples demonstrating how to build and test Firecracker microVMs using both initramfs and ext4 rootfs configurations.

## Overview
The `examples` directory serves as a foundational reference for integrating `rules_firecracker` into a Bazel workspace. It illustrates the complete lifecycle of creating lightweight virtual machines, from assembling static assets and initialization scripts to defining build targets and executing integration tests. By showcasing two distinct root filesystem strategies—initramfs and ext4—it helps developers understand how to configure kernel command lines, manage mounts, and verify VM output in automated CI pipelines.

## Deep Dive
### Build Configuration
The `hello/` subdirectory defines four primary targets: `hello_initrd`, `hello_vm`, `hello_test`, and their ext4 counterparts (`hello_rootfs`, `hello_rootfs_vm`, `hello_rootfs_test`). The initramfs target packages `greeting.txt` and `hello_init.sh` into a compressed archive, while the ext4 target constructs a read-write filesystem image using BusyBox binaries. These targets leverage `firecracker_initramfs`, `firecracker_rootfs`, and `firecracker_microvm` rules to handle image creation and VM instantiation.

### Initialization Scripts
Both `hello_init.sh` and `hello_rootfs_init.sh` act as PID 1 entry points. They perform essential housekeeping, such as mounting the `/proc` filesystem to ensure standard Linux utilities function correctly. After verifying environment accessibility, they print specific markers (`HELLO_FROM_INITRD` or `HELLO_FROM_ROOTFS`) to stdout. Finally, they execute a forced reboot (`reboot -f`), which terminates the VM session cleanly due to the `reboot=k` kernel argument, allowing the test harness to detect successful boot completion.

### Testing Workflow
Tests are defined using the `firecracker_test` rule, which boots the respective VM and captures its serial output. The test logic verifies that expected markers appear in the log and ensures no kernel panics occur. This setup validates that the VM can start, access necessary resources, and exit gracefully, providing a robust smoke test for the Firecracker integration.

### k3s Smoke Test
The `k3s_smoke/` directory implements a smoke test that boots a single-node k3s cluster inside a Firecracker microVM. It combines a Bazel build configuration with a Go binary designed to run inside the guest VM. The primary goal is to ensure that the kubeconfig is accessible and that at least one node reports a `Ready` status, serving as a critical health check in the CI pipeline.

### Guest-Side Validation
The `main.go` binary executes inside the microVM after k3s initialization. It orchestrates two main checks: verifying the existence of the kubeconfig file and polling for node readiness. The `waitNodeReady` function retries every 2 seconds using `kubectl get nodes` until a node reports `Ready=True` or a 60-second timeout expires. Results are serialized into a JSON report written to `/tmp/report.json`, enabling automated harnesses to determine success or failure based on pass conditions.

## Key Interfaces
- `//examples/hello:hello_vm` - MicroVM target using initramfs with 128 MiB memory.
- `//examples/hello:hello_rootfs_vm` - MicroVM target using ext4 rootfs with read-write mount.
- `//examples/hello:hello_test` - Test target verifying initramfs boot markers.
- `//examples/hello:hello_rootfs_test` - Test target verifying ext4 boot markers.
- `k3s_smoke`: Public static Go binary embedded with the library.
- `k3s_smoke_lib`: Private Go library wrapping `main.go` for internal referencing.
- `k3s_smoke_test`: Primary test target running the scenario with a 300-second timeout.
- `reportPC`: Struct representing a single Pass Condition with ID, label, status, and error message.
- `report`: Top-level structure containing the scenario name and list of pass conditions.

## Dependencies
- `//firecracker:defs.bzl` - Core definitions for Firecracker rules and default kernel cmdline.
- `busybox` - Used in the ext4 rootfs for basic utilities and the init script.
- `rules_go` - Go build rules for static linking.
- `k3s` - The Kubernetes distribution being tested.
- `kubectl` - Command-line tool used for node verification.

## Subcomponents
- `hello/BUILD.bazel` - Bazel build definitions for VMs and tests.
- `hello/greeting.txt` - Static asset containing the greeting message.
- `hello/hello_init.sh` - Init script for the initramfs-based VM.
- `hello/hello_rootfs_init.sh` - Init script for the ext4-based VM.
- `k3s_smoke/BUILD.bazel` - Bazel build configuration.
- `k3s_smoke/main.go` - Guest-side validation logic.