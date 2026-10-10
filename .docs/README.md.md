<!-- docdaemon ts:2026-10-10T19:04:44Z hash:97fd264247efc855 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file documents the `rules_firecracker` Bazel module for building and testing Firecracker microVMs.

It defines macros like `firecracker_initramfs`, `firecracker_microvm`, and `firecracker_test` to create bootable VM images and run console-based assertions. The rules handle kernel compilation, rootfs generation (ext4/initramfs), and OCI container flattening into guest filesystems. It supports single-VM tests, multi-node k3s clusters, and network renumbering scenarios via host bridges and TAP interfaces.