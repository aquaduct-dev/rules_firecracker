<!-- docdaemon ts:2026-10-10T19:05:04Z hash:4046d6aa0fc3c623 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file is the guest-side test binary that validates Firecracker K3s extras by verifying flag contracts, applied manifests, installed files, executables, and imported container images.

## Purpose
The `k3s_extras` binary runs inside the VM to ensure that all `extra_*` attributes defined in the host-side `firecracker_k3s_test` are correctly propagated and functional within the guest environment. It produces a JSON report at `/tmp/report.json` detailing pass/fail conditions for downstream CI analysis.

## Key Components

### Types
- **`report`**: Aggregates the scenario name and a list of `pc` structs representing individual test outcomes.
- **`pc`**: Represents a single pass condition with an ID, label, boolean status, and optional error message.

### Functions
- **`kubectl`**: Wraps the `k3s kubectl` command using a specified kubeconfig to interact with the cluster.
- **`poll`**: Retries a given function every 2 seconds until it succeeds or a timeout expires. Used for asynchronous checks like manifest application and image import.
- **`check`**: Records the result of a test function into the report's `PassConditions`.

### Main Logic
1. **Flag Validation**: Verifies that the launcher provided the correct `--scenario`, `--kubeconfig`, and `--namespace` flags as per the contract.
2. **Manifest Check**: Polls for a specific ConfigMap marker (`fc-fixture`) to confirm `extra_manifests` were applied.
3. **File Check**: Reads `/etc/fcextra/data.txt` to verify content and permissions (0644) for `extra_files`.
4. **Executable Check**: Runs `/opt/extra/busybox` to confirm `extra_execs` are executable (0755).
5. **Image Check**: Polls `ctr images ls` to ensure `fctest/extra:latest` was auto-imported into containerd from local storage.