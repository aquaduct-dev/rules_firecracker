<!-- docdaemon ts:2026-10-15T22:44:10Z hash:267d124276022089 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file serves as the public API entry point for the Firecracker Bazel rules, re-exporting core macros from internal implementation details.

It provides a clean interface for users to load and utilize rules for booting Linux VMs via Firecracker. The module exposes several key rule types categorized by their function:

*   **Image Building**: `firecracker_initramfs` and `firecracker_rootfs` are used to construct bootable disk images.
*   **VM Execution**: `firecracker_microvm` creates a runnable microVM instance, while `firecracker_container` handles OCI image-based VMs.
*   **Testing Suites**: 
    *   `firecracker_test`: Runs tests against a single VM.
    *   `firecracker_k3s_test`: Tests against a k3s cluster within a VM.
    *   `firecracker_cluster_test`, `firecracker_renumber_test`, and `firecracker_install_cluster_test`: Manage multi-VM networked environments for complex testing scenarios.

The file imports these definitions from `//firecracker/private:macros.bzl` to hide implementation complexity. It also exports `DEFAULT_KERNEL_CMDLINE`, providing a standard kernel command line configuration for VMs. Users should load this file in their BUILD files to access these rules without needing to know the internal package structure.