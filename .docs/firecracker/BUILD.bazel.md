<!-- docdaemon ts:2026-10-10T19:04:52Z hash:17c3fac4d022f474 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines the public Bazel targets for rules_firecracker, exposing guest kernels, binaries, and rootfs generation tools while hiding implementation details.

It serves as the primary entry point for consumers of this module. The `bzl_library` target exposes `defs.bzl`, which contains the high-level macros driving the build system. Platform-agnostic access to the Firecracker binary is provided via the `firecracker` alias, which resolves to either x86_64 or aarch64 specific repositories based on the current CPU platform.

The file explicitly builds and exposes several static binaries required for testing and image creation:
*   **vmlinux**: A Linux 6.1.155 kernel built from source using a pinned configuration and toolchain. It is cached for performance but not marked local.
*   **busybox_static**, **k3s_binary**, and **jq**: Pinned upstream binaries made executable and accessible for use in test scripts and rootfs construction.

Additionally, it exposes shell scripts for generating various root filesystem images (e.g., `mkrootfs`, `mkk3srootfs`) and initialization scripts (`k3s_init`). All implementation scripts, templates, and private macros are located under `private/` and are excluded from the public API.