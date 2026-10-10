<!-- docdaemon ts:2026-10-10T19:04:51Z hash:27104d7410801eff model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file serves as the public API entry point for `rules_firecracker`, exposing Starlark macros to build and test Firecracker microVMs.

It re-exports core rules and tests from the private implementation module (`//firecracker/private:macros.bzl`) to make them available to user workspaces via standard `load` statements. The file defines a consistent namespace for interacting with the Firecracker toolchain, separating internal implementation details from the public interface.

### Exposed Symbols

The following symbols are made available for use in `BUILD` files:

**Image Rules**
*   `firecracker_initramfs`: Builds an initial RAM filesystem image.
*   `firecracker_rootfs`: Builds a root filesystem image.

**VM Rules**
*   `firecracker_microvm`: Defines a single microVM target.
*   `firecracker_container`: Defines a container-based VM target.

**Test Rules**
*   `firecracker_test`: Runs a basic microVM test.
*   `firecracker_k3s_test`: Runs a test involving K3s.
*   `firecracker_cluster_test`: Tests a cluster of multiple microVMs.
*   `firecracker_renumber_test`: Tests VM renumbering scenarios.
*   `firecracker_install_cluster_test`: Tests cluster installation procedures.

**Constants**
*   `DEFAULT_KERNEL_CMDLINE`: A constant string providing default kernel command-line arguments.