<!-- docdaemon ts:2026-10-10T19:04:57Z hash:949b446ee6fc770a model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script serves as the initialization entry point for a node booted from its installed disk, verifying system integrity and network connectivity before signaling readiness.

## Purpose
The script acts as `/sbin/init` for nodes running from their `INSTALLED` disk (`root=/dev/vda2`). It ensures the environment is correctly mounted, validates that the root device matches expectations, retrieves configuration injected by the installer, and confirms reachability to the peer node.

## Key Functions
- **Environment Setup**: Mounts `proc` and `sysfs`, and brings up the loopback interface using BusyBox utilities.
- **Configuration Parsing**: Extracts the local IP address (`ip=`) and peer IP address (`fc.peer=`) from the kernel command line (`/proc/cmdline`).
- **Device Verification**: Compares the device number of the actual root mount (`/`) against the expected `/dev/vda2` device number to ensure the correct partition is active.
- **Secret Retrieval**: Reads the cluster secret from `/etc/installed-settings`. The value is masked in logs, showing only the first four characters.
- **Peer Connectivity Check**: Attempts to ping the peer node up to 20 times with a 1-second interval.

## Integration
This script is part of the cluster installation workflow. It runs after the OS is written to disk and the node reboots. Successful execution (indicated by `INSTALL_BOOT_OK`) confirms the node is properly configured and connected to its peer, allowing the cluster formation process to proceed. Failure results in `INSTALL_BOOT_FAILED` and an immediate forced reboot.