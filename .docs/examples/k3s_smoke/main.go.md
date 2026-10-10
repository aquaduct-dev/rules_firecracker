<!-- docdaemon ts:2026-10-10T19:04:52Z hash:7e4288037a611a4d model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This binary validates that a k3s microVM is fully operational by verifying kubeconfig accessibility and node readiness.

### Purpose
`k3s_smoke` runs inside the guest microVM after `k3s` initialization to assert cluster health. It produces a JSON report indicating pass/fail status for specific pass conditions, enabling automated test harnesses to determine VM boot success.

### Key Components

*   **`main`**: Orchestrates the smoke test. It checks for the existence of the kubeconfig file and waits for at least one node to report `Ready=True`. It exits with code 1 on failure, writing a detailed error report.
*   **`waitNodeReady`**: Polls `/usr/local/bin/k3s kubectl get nodes` using a custom JSONPath query. It retries every 2 seconds until a node is ready or the timeout (default 60s) expires.
*   **`hasReady`**: Parses the tab-separated output from `kubectl`, checking if any line ends with `True`.
*   **`writeReport`**: Serializes the `report` struct to JSON and writes it to the specified path (`/tmp/report.json` by default).

### Types

*   **`reportPC`**: Represents a single Pass Condition with an ID, label, boolean status, and optional error message.
*   **`report`**: The top-level structure containing the scenario name and a list of pass conditions.

### Integration
The binary is statically linked (cgo-free) to run on a minimal busybox rootfs. It is invoked by the host-side `firecracker_k3s_test` target as part of the CI pipeline.