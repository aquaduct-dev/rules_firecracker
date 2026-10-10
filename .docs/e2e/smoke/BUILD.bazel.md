<!-- docdaemon ts:2026-10-10T19:04:48Z hash:2a5859c16fb91b4c model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This Bazel build file defines the targets required to execute smoke tests for Firecracker microVMs, including an initramfs, a VM configuration, and both KVM-based and user-space validation tests.

### Purpose
The file orchestrates the build and test lifecycle for end-to-end (E2E) smoke testing. It ensures that a minimal Linux environment can boot within a Firecracker instance and verifies the binary version when hardware acceleration is unavailable.

### Key Targets

*   **`initrd`**: Builds an initial RAM filesystem using `firecracker_initramfs`. It packages `init.sh` as the entry point, providing the necessary userspace for the guest kernel.
*   **`vm`**: Defines the virtual machine configuration via `firecracker_microvm`. It attaches the `:initrd`, allocates 128 MiB of memory, and provisions 2 vCPUs. The kernel and Firecracker binary are resolved from the default rules package.
*   **`boot_test`**: Executes the primary E2E test using `firecracker_test`. It runs the `:vm` target and expects the output marker `E2E_SMOKE_OK nproc=2` to confirm successful boot and execution.
*   **`firecracker_version_test`**: A fallback `sh_test` designed for environments without KVM support (e.g., BCR presubmits). It locates the pinned Firecracker binary via runfiles (`$(rlocationpath ...)`) and validates its version using `firecracker_version_test.sh`.