<!-- docdaemon ts:2026-10-10T19:06:00Z hash:14f5d26961be8847 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains the Bazel build rules and shell-based unit tests for validating image builders, test generators, and the microVM launcher in isolation.

## Overview
The `tests/unit` directory orchestrates a suite of shell scripts that verify the correctness of helper utilities and configuration generation logic without requiring KVM or actual VM execution. By mocking the Firecracker binary and simulating VM boot scenarios, these tests ensure that scripts like `mkrootfs`, `mkinitramfs`, and the launcher behave correctly before integration testing with real hardware. This approach provides fast, deterministic feedback on script integrity, argument parsing, and file system manipulation.

## Deep Dive
### Image Builder Validation
Tests for `mkinitramfs`, `mkrootfs`, `mkk3srootfs`, and `mkcontainerfs` verify that these tools correctly generate ext4 images and CPIO archives. They check for proper file permissions, symlink creation, and error handling for invalid inputs like dynamically linked binaries. The container filesystem test specifically validates layer merging, whiteout handling, and init script generation by constructing manual OCI layouts.

### Launcher and VMM Simulation
The `runner_test` exercises the microVM launcher logic using a fake Firecracker binary (`fake_firecracker.sh`) that captures invocation arguments and dumps VM configurations. Custom `firecracker_microvm` targets simulate boot scenarios with dummy kernels and disk images, allowing end-to-end testing of configuration generation, networking setup, and environment variable propagation without virtualization overhead.

### Test Generation Utilities
Scripts `gen_test_test` and `gen_k3s_test_test` validate the test generation tools that produce runner scripts. These tests ensure that generated scripts correctly handle lifecycle events, timeout enforcement, marker detection, and report extraction from JSON outputs. They verify strict type checking and error handling for malformed inputs.

### Shared Infrastructure
`testlib.sh` provides shared assertion helpers, ELF inspection utilities, and ext4 image interaction functions. It manages the test environment and tracks pass/fail counts, ensuring consistent validation across all test targets.

## Key Interfaces
- `BUILD.bazel`: Defines `sh_test` and custom `firecracker_microvm` rules for the test suite.
- `fake_firecracker.sh`: Mock VMM implementation that records arguments and simulates VM behavior.
- `testlib.sh`: Shared library for assertions, ELF checks, and ext4 image inspection.
- `*_test.sh`: Individual test scripts for each builder, generator, and launcher component.

## Dependencies
- `//firecracker:defs.bzl`: Custom Bazel macros for microVM simulation.
- `busybox_static`: Static BusyBox binary used in initramfs and rootfs tests.
- `jq`: JSON processing tool used in test generation and validation.
- `rlocation`: Bazel runfiles resolution mechanism for locating artifacts at runtime.

## Subcomponents
- `BUILD.bazel`: Bazel build definitions.
- `fake_firecracker.sh`: Mock Firecracker binary.
- `firecracker_binary_test.sh`: Binary integrity validation.
- `gen_k3s_test_test.sh`: K3s test generator validation.
- `gen_test_test.sh`: General test generator validation.
- `mkcontainerfs_test.sh`: Container filesystem builder validation.
- `mkinitramfs_test.sh`: Initramfs builder validation.
- `mkk3srootfs_test.sh`: K3s rootfs builder validation.
- `mkrootfs_test.sh`: Standard rootfs builder validation.
- `runner_test.sh`: MicroVM launcher validation.
- `testlib.sh`: Shared test utilities.