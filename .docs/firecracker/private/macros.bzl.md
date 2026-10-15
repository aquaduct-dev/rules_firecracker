<!-- docdaemon ts:2026-10-15T22:44:08Z hash:fb212edf99feca13 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file implements internal Starlark macros for building and testing Firecracker microVMs.

It provides rules to create initramfs (`firecracker_initramfs`) and ext4 root filesystems (`firecracker_rootfs`), launch VMs (`firecracker_microvm`), and run various tests including console output checks (`firecracker_test`), OCI container booting (`firecracker_container`), k3s integration (`firecracker_k3s_test`), and multi-node cluster scenarios (`firecracker_cluster_test`, `firecracker_renumber_test`, `firecracker_install_cluster_test`). These macros generate shell scripts and genrules to handle VM configuration, disk image creation, and test execution logic.