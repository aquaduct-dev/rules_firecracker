<!-- docdaemon ts:2026-10-10T19:04:55Z hash:564dcc73b8eac996 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script serves as the PID 1 init process for multi-node k3s Firecracker microVMs, orchestrating cluster formation via kernel command-line parameters.

### Purpose and Role
Unlike single-node initializers, this file boots on a real `eth0` interface connected to a shared bridge, enabling genuine server-agent clustering over virtio-net. It parses `ofd.role`, `ofd.node`, `ofd.token`, and `ofd.server` from `/proc/cmdline` to determine whether the VM acts as a control plane node or a worker agent.

### Key Functions
- **Environment Setup**: Mounts essential filesystems (`proc`, `sysfs`, `devtmpfs`) and configures network routes based on kernel IP arguments.
- **Role Dispatch**:
  - **Server**: Starts `k3s server` with specific CIDR ranges, disables unnecessary components (traefik, metrics-server), and waits for a configured number of nodes to reach `Ready` status using `kubectl`.
  - **Agent**: Starts `k3s agent` pointing to the server IP, logs initial startup output, and exits after a timeout to allow the orchestrator to proceed.
- **Status Reporting**: Emits console markers (`K3SC_BOOTING`, `K3SC_CLUSTER_READY`, `K3SC_CLUSTER_FAILED`) for the external orchestrator to grep and monitor cluster health.

### Integration
The script is invoked directly by the Firecracker runtime as the guest's init process. It relies on `cluster_run.sh` to set the kernel cmdline and handles the lifecycle until the cluster state is verified or timed out, triggering a forced reboot to signal completion to the host.