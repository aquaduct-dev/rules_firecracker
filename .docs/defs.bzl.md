<!-- docdaemon ts:2026-10-09T22:29:01Z hash:9c7d8d33aeebfd97 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file provides Bazel macros to build, boot, and test Firecracker microVMs, including single-node k3s clusters and multi-VM networking scenarios.

It defines public APIs for creating initramfs (`firecracker_initramfs`) and ext4 rootfs images (`firecracker_rootfs`), then wraps them in runnable `sh_binary` targets via `firecracker_microvm`. Testing is handled by `firecracker_test`, which asserts serial console output against expected markers.

Specialized macros support higher-level workloads: `firecracker_container` boots OCI images with a generated init script, while `firecracker_k3s_test` provisions a single-node Kubernetes cluster for integration testing. For complex networking validation, the file includes `firecracker_cluster_test`, `firecracker_renumber_test`, and `firecracker_install_cluster_test`, which orchestrate multiple VMs on shared bridges to verify cluster formation, IP renumbering resilience, and disk installation workflows. All tests require KVM access and are tagged accordingly to skip on unsupported hosts.