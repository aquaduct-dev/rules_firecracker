<!-- docdaemon ts:2026-10-09T22:28:52Z hash:594213c9137ebc8f model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script serves as the PID 1 entry point for Firecracker VMs in a multi-VM networking self-test, verifying end-to-end connectivity between peers.

### Purpose
The script initializes the environment by mounting `/proc` and `/sys`, then parses the kernel command line to extract its own IP address (`SELF`) and its peer's IP address (`PEER`). It ensures the loopback interface is active before attempting to establish network connectivity.

### Key Functions
*   **Configuration Parsing**: Extracts `ip=` and `ofd.peer=` parameters from `/proc/cmdline` using `sed`. The kernel handles the initial configuration of `eth0` via `CONFIG_IP_PNP`.
*   **Connectivity Verification**: Attempts to ping the `PEER` IP up to 15 times with a 1-second interval.
*   **Status Reporting**: Prints `NETOK` or `NETFAIL` markers to stdout, which the orchestrator greps to determine test success.
*   **Termination**: Calls `poweroff -f` immediately after reporting status to halt the VM.

### Integration
This file acts as the primary process for each VM in the test suite. Two instances running on the same bridge ping each other to prove the multi-VM substrate works end-to-end, satisfying the "No stub tests" amendment criteria.