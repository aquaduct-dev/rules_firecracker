<!-- docdaemon ts:2026-10-09T22:28:53Z hash:46d2feba248a45d7 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script initializes a single-node k3s microVM, waits for cluster readiness, applies manifests, and executes the guest test binary before powering off.

### Purpose
Runs as PID 1 inside a Firecracker microVM to provision a deterministic Kubernetes environment for integration testing. It bridges host-provided artifacts (images, manifests, test binaries) with the k3s runtime.

### Key Functions
- **Environment Setup**: Mounts necessary filesystems (`proc`, `sysfs`, `cgroup2`), sets hostname, and configures a dummy network interface (`fakenet`) to satisfy kubelet requirements without real networking.
- **Image Preloading**: Copies OCI tarballs from `/etc/images` into k3s' auto-import directory.
- **Cluster Boot**: Starts k3s server in the background with minimal addons (no traefik, metrics-server, or helm controller) to reduce resource usage and flakiness.
- **Readiness Check**: Polls until the node reports `Ready` within a 240-second deadline.
- **Test Execution**: Applies baked-in YAML manifests, runs the specified test binary, and captures JSON reports to stdout markers for the host harness.

### Integration
The host launcher (`gen_k3s_test.sh`) scrapes `/dev/console` output. Markers like `K3S_READY` and `===REPORT_BEGIN===` delineate the lifecycle stages, allowing the host to parse test results verbatim.