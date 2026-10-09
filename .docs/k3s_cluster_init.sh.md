<!-- docdaemon ts:2026-10-09T22:28:52Z hash:4c30167507196b7c model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script serves as the PID 1 init process for k3s microVMs, booting either a server or agent node based on kernel command-line parameters.

It parses `ofd.role`, `ofd.node`, and `ofd.token` from `/proc/cmdline` to configure the environment. It mounts essential filesystems (`proc`, `sysfs`, `devtmpfs`) and configures networking via `eth0`.

For **server** roles, it launches `k3s server` with specific network and disable flags, then polls `kubectl get nodes` until `EXPECT` nodes are Ready or a deadline expires. For **agent** roles, it starts `k3s agent`, waits briefly for initialization, logs status, and powers off.

The script emits console markers (`K3SC_BOOTING`, `K3SC_CLUSTER_READY`, etc.) for orchestrator monitoring before powering off the VM upon completion.