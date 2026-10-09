<!-- docdaemon ts:2026-10-09T22:28:57Z hash:7e4288037a611a4d model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This binary validates that a k3s cluster is operational inside a microVM by verifying kubeconfig availability and node readiness.

### Purpose
`k3s_smoke` serves as the guest-side test agent for the `firecracker_k3s_test` smoke target. It runs within the microVM after initialization to assert cluster health, producing a structured JSON report for the harness. The binary is statically linked to ensure compatibility with the minimal busybox rootfs.

### Key Components

*   **`main`**: Orchestrates the smoke test. It checks for the existence of the kubeconfig file and then waits for at least one node to report a `Ready=True` status. It exits with code 1 on failure, writing a report indicating which pass condition failed.
*   **`waitNodeReady`**: Polls `/usr/local/bin/k3s kubectl get nodes` using a custom JSONPath query. It retries every 2 seconds until the timeout expires or a ready node is detected.
*   **`hasReady`**: Parses the tab-separated output from the kubectl command to identify if any node has a `True` status in its Ready condition.
*   **`writeReport`**: Serializes the `report` struct into indented JSON and writes it to the specified path (`/tmp/report.json` by default).

### Data Structures

*   **`reportPC`**: Represents a single Pass Condition (ID, Label, Passed status, and optional Error message).
*   **`report`**: Contains the scenario name and a list of `PassConditions`.

### Integration
The resulting report is consumed by the host-side test harness to determine if the `boot.k3s-ready` pass condition succeeded.