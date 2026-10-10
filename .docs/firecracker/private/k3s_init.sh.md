<!-- docdaemon ts:2026-10-10T19:04:56Z hash:769c3745e2f9fdc8 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script initializes a single-node k3s microVM, preloads container images, waits for cluster readiness, applies manifests, and executes the guest test binary.

### Purpose
It serves as PID 1 inside the `firecracker_k3s_test` microVM, orchestrating the lifecycle of a deterministic Kubernetes environment for integration testing. It ensures the host launcher can scrape structured JSON reports via `/dev/console`.

### Key Functions
- **Environment Setup**: Mounts proc/sysfs/devtmpfs, configures cgroup v2, sets hostname to `server0`, and creates a dummy network interface (`fakenet`) with IP `10.42.0.10` to satisfy kubelet requirements without real networking.
- **Image Preloading**: Copies `.tar`/`.tgz` files from `/etc/images/` into k3s' auto-import directory before starting the server.
- **K3s Launch**: Starts k3s in the background with flags disabling unnecessary addons (traefik, metrics-server) and configuring `host-gw` flannel. Logs are redirected to `/var/log/k3s.log` to prevent interleaving with console markers.
- **Readiness Check**: Polls until the `k3s.yaml` kubeconfig exists and `kubectl get nodes` reports `server0` as Ready within a 240-second deadline.
- **Test Execution**: Applies YAML manifests from `/etc/manifests/`, then runs the test binary specified in `/etc/test_binary` (defaulting to `thirdeyetest`).
- **Reporting & Teardown**: Outputs structured markers (`SCENARIO_BEGIN`, `===REPORT_BEGIN===`, etc.) to `/dev/console`. On failure or completion, it triggers a forced reboot to signal Firecracker to exit.