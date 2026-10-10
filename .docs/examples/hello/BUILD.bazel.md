<!-- docdaemon ts:2026-10-10T19:04:48Z hash:7b0e8742e19ba0a7 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This Bazel build file defines the targets to create, boot, and test two minimal Firecracker microVM configurations.

It establishes a complete testing workflow for `rules_firecracker` by defining both initramfs-based and ext4 rootfs-based virtual machines. The file loads necessary definitions from `//firecracker:defs.bzl`, including `DEFAULT_KERNEL_CMDLINE` and specific rule types like `firecracker_initramfs`, `firecracker_microvm`, `firecracker_rootfs`, and `firecracker_test`.

The first configuration uses an initramfs (`hello_initrd`) containing a greeting file and an initialization script. It is booted via `hello_vm` with 128 MiB of memory. A corresponding test (`hello_test`) verifies that the VM outputs expected markers ("HELLO_FROM_INITRD" and "GREETING=hello, firecracker") and does not panic.

The second configuration builds a static ext4 rootfs (`hello_rootfs`) using BusyBox and a custom init script. This rootfs is attached to a separate microVM target (`hello_rootfs_vm`) which modifies the kernel command line to mount the root filesystem read-write and use `/sbin/init`. A dedicated test (`hello_rootfs_test`) ensures the rootfs-based VM correctly outputs the "HELLO_FROM_ROOTFS" marker.