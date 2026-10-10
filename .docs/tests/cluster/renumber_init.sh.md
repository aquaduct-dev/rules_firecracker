<!-- docdaemon ts:2026-10-10T19:04:59Z hash:c32bca4e07b1cc64 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script serves as the `/sbin/init` entry point for the renumber test, managing identity persistence and network verification across potential IP changes.

### Purpose
The script initializes a minimal environment using BusyBox to support a "rootfs mode" test scenario where a node may be renumbered (assigned a new IP) while retaining its persistent identity. It distinguishes between a first-time boot and a recovery from a previous state by checking a persistent disk (`/dev/vdb`).

### Key Logic
1.  **Environment Setup**: Mounts `proc`, `sysfs`, and `devtmpfs`, then brings up the loopback interface.
2.  **Configuration Parsing**: Extracts the current node's IP (`SELF`) and the peer's IP (`PEER`) from the kernel command line.
3.  **State Determination**:
    *   **New Identity**: If `/persist/ip` does not exist, it generates a UUID, saves both the ID and current IP to `/persist/id` and `/persist/ip`, and reports formation status.
    *   **Existing Identity**: If `/persist/ip` exists, it reads the old IP and ID. It attempts to reach the peer via `ping_peer`.
4.  **Verification**: The `ping_peer` function retries connectivity up to 20 times with a 1-second interval. Success results in a "heal" marker containing the old IP, confirming the network works despite the change. Failure logs an error.

### Integration
This file acts as the isolated init process for the `renumber_init` test case. It ensures that after a simulated renumbering event, the node can still communicate with its peer and correctly report its historical identity, validating the system's ability to handle IP address changes without losing context.