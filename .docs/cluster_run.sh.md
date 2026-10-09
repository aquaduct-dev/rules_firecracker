<!-- docdaemon ts:2026-10-09T22:28:59Z hash:cadf7e8d6b9264a0 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
`cluster_run.sh` orchestrates the lifecycle of multiple Firecracker microVMs on a shared host bridge, handling network setup, boot configuration, and cleanup.

### Purpose
This script serves as the foundation for multi-VM integration tests ("No stub tests"). It creates an isolated network environment using a Linux bridge and TAP devices, allowing Firecracker VMs to communicate without requiring `CAP_NET_ADMIN` inside the guest. It manages the full lifecycle: provisioning resources, launching VMs via a specified runner, waiting for completion, and tearing down all infrastructure.

### Key Functions
*   **Argument Parsing**: Accepts configuration for the runner binary, bridge name, subnet gateway, timeout, log directory, and persistent disk paths. It supports multiple `--node` arguments to define individual VM specifications (ID, IP, MAC, extra cmdline).
*   **Network Setup**: Creates a bridge (`ofdbr0` by default) and assigns a TAP device to each node. The TAP devices are attached to the bridge and owned by the current user to bypass privilege requirements for Firecracker.
*   **Disk Management**: Optionally initializes persistent data disks (`FC_PERSIST_DISK`) and boot disks (`FC_BOOT_DISK`) if directories are provided, ensuring state survives reboots or IP changes.
*   **VM Execution**: Launches each VM in the background using the provided `--runner`, passing necessary environment variables (`FC_TAP`, `FC_GUEST_MAC`, `FC_CMDLINE_EXTRA`). It waits for all processes to exit before completing.
*   **Cleanup**: A trap ensures that all TAP devices and the bridge are deleted upon script exit, preventing resource leaks.

### Integration
This script is designed to run unsandboxed with passwordless sudo. It is typically invoked directly or as part of a Bazel test suite. It relies on `firecracker_microvm_runner` (specified via `--runner`) to handle the actual VM instantiation, using environment variables to configure networking and storage.