<!-- docdaemon ts:2026-10-10T19:04:44Z hash:558fac5a41de87f7 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines Starlark rules for building Firecracker microVM images, containers, and integration tests within a Bazel build system.

It provides macros to package initramfs (`firecracker_initramfs`) and ext4 rootfs (`firecracker_rootfs`) images, and to launch runnable microVMs (`firecracker_microvm`). It supports booting OCI images directly as VMs via `firecracker_container`.

Testing capabilities include single-VM assertions (`firecracker_test`), multi-node cluster networking (`firecracker_cluster_test`, `firecracker_renumber_test`), OS installation verification (`firecracker_install_cluster_test`), and k3s Kubernetes server validation (`firecracker_k3s_test`). All tests require KVM access and are tagged accordingly.