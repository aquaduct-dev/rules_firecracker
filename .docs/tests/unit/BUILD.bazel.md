<!-- docdaemon ts:2026-10-10T19:05:05Z hash:fce00c6ad18cfcc9 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines the Bazel build rules for unit tests that validate image builders, test script generators, and the microVM launcher without requiring KVM or actual VM execution.

### Purpose
The `BUILD.bazel` file in `tests/unit/` orchestrates a suite of shell-based tests (`sh_test`) and custom microVM rule instantiations (`firecracker_microvm`). These tests verify the correctness of helper scripts and configuration generation logic in isolation, ensuring they function correctly before integration testing with real hardware acceleration.

### Key Components

**Shared Configuration**
*   `_COMMON_DATA`: A list of shared dependencies including `testlib.sh`, `busybox_static`, and `jq`.
*   `_COMMON_ENV`: Environment variables mapping runfiles paths (RLOCs) for BusyBox and JQ, used across multiple test targets.
*   `_RUNFILES`: Dependency on Bazel's runfiles library to resolve file paths at runtime.

**Test Targets**
1.  **Binary & Script Generators**:
    *   `firecracker_binary_test`: Validates the Firecracker binary itself.
    *   `mkinitramfs_test`, `mkrootfs_test`, `mkk3srootfs_test`, `mkcontainerfs_test`: Test the respective image generation scripts (`mkinitramfs`, `mkrootfs`, etc.) by providing their source scripts and required data artifacts (e.g., `initrd`, `rootfs`, `k3s_init`).
    *   `gen_test_test`, `gen_k3s_test_test`: Validate test generation utilities.

2.  **Launcher Tests**:
    *   `runner_test`: Exercises the microVM runner logic using fake VM configurations.
    *   `fake_initrd_vm`, `fake_rootfs_vm`, `fake_rootfs_extra_vm`: Custom `firecracker_microvm` targets configured with `fake_firecracker.sh`, `fake_kernel.bin`, and dummy disk images. These simulate VM boot scenarios without actual virtualization, allowing the launcher code to be tested end-to-end.

### Integration
This file sits within the `tests/` directory structure, specifically targeting unit-level validation. It relies on definitions from `//firecracker:defs.bzl` for the custom `firecracker_microvm` rule, enabling complex VM setup simulation within the Bazel test environment.