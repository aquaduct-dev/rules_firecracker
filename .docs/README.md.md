<!-- docdaemon ts:2026-10-15T22:44:10Z hash:be94bd8e30a32db5 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file documents `rules_firecracker`, a Bazel module for booting Linux VMs in tests using Firecracker microVMs.

It provides macros like `firecracker_test` and `firecracker_microvm` to define, build, and run isolated VM environments. The rules handle downloading pinned binaries, configuring kernels, and managing network bridges for multi-node clusters. It supports various boot methods including initramfs, ext4 rootfs, and OCI container images, enabling integration testing for k3s clusters and custom installers.