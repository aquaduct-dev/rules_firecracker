<!-- docdaemon ts:2026-10-10T19:04:57Z hash:cf6ecb011b2ead9b model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script serves as the PID 1 entry point for Firecracker networking self-test VMs, validating end-to-end connectivity between paired instances.

## Purpose
The script initializes a minimal environment to verify that two VMs connected via a shared bridge can communicate. It acts as the orchestrator's heartbeat mechanism by printing `NETOK` or `NETFAIL` markers based on ping success.

## Key Functions

### Environment Setup
Mounts `proc` and `sysfs` filesystems to ensure kernel interfaces are accessible. This is critical because the kernel configures `eth0` using the `ip=` command-line argument (CONFIG_IP_PNP).

### Configuration Parsing
Extracts network parameters from `/proc/cmdline`:
- **Self IP**: Parsed from the `ip=` parameter.
- **Peer IP**: Parsed from the `ofd.peer` parameter.

### Connectivity Verification
1. Brings up the loopback interface (`lo`).
2. Logs initial state, including self/peer IPs and active interfaces.
3. Enters a retry loop (up to 15 iterations) attempting a single ICMP ping to the peer with a 1-second timeout.
4. Sets a success flag if the ping succeeds.

### Result Reporting
Prints a status marker in the format `NETOK <self>-><peer>` or `NETFAIL <self>-><peer>`. The orchestrator greps these outputs to determine test success. Finally, it forces a reboot to clean up the VM state.