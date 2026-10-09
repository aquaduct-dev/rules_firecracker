<!-- docdaemon ts:2026-10-09T22:28:59Z hash:a75d5c4ff481b418 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file provides Bazel rules for building Firecracker microVM images and executing tests within them.

It defines public APIs in `defs.bzl` for creating initramfs and ext4 rootfs, managing a pinned 6.1 guest kernel, and running single-node or multi-node k3s cluster tests on a host bridge.

Usage requires adding the module to `MODULE.bazel` and loading specific macros like `firecracker_k3s_test`. Tests are tagged `requires-kvm` and must be run with the `--config=kvm` flag after configuring `.bazelrc`.

Host requirements include x86_64 Linux with KVM support, necessary build tools for the kernel, and passwordless sudo for network bridge setup in cluster tests.