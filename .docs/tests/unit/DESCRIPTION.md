<!-- docdaemon ts:2026-10-19T23:25:03Z hash:c0236a9308ec2b99 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains a comprehensive suite of shell-based unit tests that validate image builders, test generators, and the microVM launcher in isolation.

## Overview
The tests ensure correctness of helper scripts and configuration generation logic without requiring KVM or actual VM execution. By mocking the Firecracker binary and simulating VM boot scenarios, the suite verifies end-to-end launcher behavior and image integrity before integration testing with real hardware.

## Deep Dive
### Image Builder Validation
Tests for `mkinitramfs`, `mkrootfs`, `mkk3srootfs`, and `mkcontainerfs` verify ext4 structure, permissions, and ownership. Recent changes enforce root ownership (0:0) on all guest inodes to prevent host UID leakage during build. The container filesystem test specifically validates OCI layer flattening, whiteout handling, and opaque directory semantics using `debugfs`.

### Launcher and Runner Logic
`runner_test.sh` exercises the microVM launcher using fake configurations to capture generated `vm.json` files. It verifies CPU/memory settings, network interfaces, and runtime overrides like persistent disks. Custom `firecracker_microvm` targets (`fake_initrd_vm`, etc.) simulate boot scenarios by invoking `fake_firecracker.sh`, which records arguments and simulates resource resolution.

### Test Generation Utilities
Scripts `gen_test_test.sh` and `gen_k3s_test_test.sh` validate the tools that produce microVM test scripts. They check marker detection, timeout enforcement, and error handling against a fake runner. These tests ensure generated scripts correctly interpret pass/fail conditions from runner outputs and handle malformed JSON or missing markers gracefully.

### Shared Infrastructure
`testlib.sh` provides assertion helpers, ELF inspection utilities, and ext4 analysis functions. `fake_firecracker.sh` acts as a mock VMM, outputting version strings, logging arguments, and simulating file system interactions based on environment variables.

## Key Interfaces
- `testlib.sh`: Shared shell utilities for assertions, ELF parsing, and ext4 inspection.
- `fake_firecracker.sh`: Mock VMM script capturing invocation args and state dumps.
- `BUILD.bazel`: Bazel rules defining `sh_test` and custom `firecracker_microvm` targets.

## Dependencies
- `//firecracker:defs.bzl`: Custom rule definitions for microVM simulation.
- `busybox_static`: Static BusyBox binary used in image construction tests.
- `jq`: JSON processing tool used in test generation validation.
- `rlocation`: Bazel runfiles library for resolving file paths at runtime.

## Subcomponents
- `BUILD.bazel`: Build rules for all test targets.
- `fake_firecracker.sh`: Mock virtual machine monitor.
- `firecracker_binary_test.sh`: Validates static linking and version.
- `gen_k3s_test_test.sh`: Tests k3s test generator logic.
- `gen_test_test.sh`: Tests generic microVM test generator.
- `mkcontainerfs_test.sh`: Validates OCI layer flattening.
- `mkinitramfs_test.sh`: Checks initramfs structure and permissions.
- `mkk3srootfs_test.sh`: Verifies k3s rootfs construction.
- `mkrootfs_test.sh`: Validates standard rootfs creation.
- `runner_test.sh`: Tests launcher configuration and runtime.
- `testlib.sh`: Shared test utilities and assertions.