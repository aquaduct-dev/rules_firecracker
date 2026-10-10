<!-- docdaemon ts:2026-10-10T19:04:53Z hash:5b09f72b9177ad83 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script orchestrates the creation of a shared network bridge and TAP devices to boot multiple Firecracker microVMs concurrently for integration testing.

### Purpose
It provides the infrastructure for "No stub tests" multi-VM rigs by managing host-side networking (bridge + TAPs) and launching VM instances via a specified runner. It ensures isolated, passwordless sudo operations for network setup and handles cleanup on exit.

### Key Functions
*   **Argument Parsing**: Accepts `--runner`, `--bridge`, `--subnet-gw`, `--timeout`, `--logdir`, and repeatable `--node` specifications (IDX:IP:MAC:EXTRA_CMDLINE). Supports optional persistent data disks (`--persist-dir`) and custom boot disks (`--boot-disk-dir`).
*   **Network Setup**: Creates a Linux bridge (`OFDBR0` default) and assigns a user-owned TAP device to each node, attaching them to the bridge. It injects an iptables rule to allow forwarding between bridge ports, bypassing Docker's default DROP policy.
*   **VM Launch**: Iterates over nodes, configuring environment variables (`FC_TAP`, `FC_GUEST_MAC`, `FC_CMDLINE_EXTRA`) and invoking the `--runner` script in the background.
*   **Cleanup**: A trap handler removes all created TAP interfaces, the bridge, and the iptables rule upon script exit or failure.

### Integration
This file is the entry point for cluster-based tests. It relies on `runner.sh.tpl` to understand the networking environment variables it generates. Logs are stored per-node in `$LOGDIR/vm<IDX>.log`.