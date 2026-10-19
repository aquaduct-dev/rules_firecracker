<!-- docdaemon ts:2026-10-19T23:24:30Z hash:459dfd7e49fb859b model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file is the guest-side smoke test binary for k3s, verifying that the microVM boots with a functional Kubernetes cluster.

### Purpose
The `k3s_smoke` binary runs inside the microVM after `k3s` starts via `/sbin/init`. It validates two critical conditions:
1. The kubeconfig at `/etc/rancher/k3s/k3s.yaml` exists and is readable.
2. At least one node reports `status.conditions[Ready]=True`.

On success, it writes a JSON report with `boot.k3s-ready` passed. On failure, it records the error reason. The binary is statically linked to run on the busybox-only rootfs.

### Key Components

*   **`main`**: Parses flags for paths and namespaces. Checks kubeconfig existence, then calls `waitNodeReady`. Appends pass/fail conditions to the report structure.
*   **`waitNodeReady`**: Polls `k3s kubectl get nodes` until timeout (default 60s). Distinguishes between API server failures (`kubectl` errors) and unready nodes. Tracks attempt counts for detailed error reporting.
*   **`hasReady`**: Parses tab-separated output from the JSONPath query to detect any node with status `True`. Uses `strings.Cut` for efficient parsing.
*   **`finish` & `writeReport`**: Ensures the host receives diagnostic data by writing the JSON report before exiting. If writing fails, it exits non-zero to signal total failure.

### Design Notes
*   **Static Linking**: No CGO dependencies allow execution in minimal environments.
*   **Diagnostic Reporting**: The report includes cumulative failure counts (command errors vs. not-ready states) to help distinguish transient network issues from persistent configuration problems.