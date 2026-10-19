<!-- docdaemon ts:2026-10-19T23:25:04Z hash:a3dac5bb34415db7 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains the integration test suite for validating that a Firecracker-based k3s guest correctly processes extra manifests, files, and container images.

## Overview
The `k3s_extras_test` target spins up a VM to verify that the launcher properly injects static assets and applies custom Kubernetes resources. It ensures that binaries are executable, files have correct ownership and permissions, and OCI images are auto-imported into containerd without external registry access. A separate failing-path test confirms that the harness correctly detects and reports deliberate failures in pass conditions.

## Deep Dive
### Extra Asset Validation
The test binary verifies three categories of injected extras. First, it checks that `/etc/fcextra/data.txt` exists with content matching `data.txt`, has `0644` permissions, and is owned by `root:root`. This ownership check was added to ensure build tools re-own inodes to `0:0` after formatting, preventing leftover build-user UIDs. Second, it runs `/opt/extra/busybox` to confirm executables are runnable with `0755` permissions. Third, it polls containerd to ensure images from `/var/lib/rancher/k3s/agent/images` are imported successfully.

### Manifest Application
The suite validates that extra YAML manifests are applied by the `k3s_init` process. It uses `fixture.yaml` to create a ConfigMap with a specific marker (`from-extra-manifest`) and `k3s_extras.yaml` as a signal file at `/etc/manifests/k3s_extras.yaml`. The guest agent checks for this signal file's presence to trigger additional validation steps, ensuring the manifest injection mechanism works end-to-end.

### Failure Reporting
The `failing/` subdirectory provides a negative test case. The guest binary intentionally fails one pass condition (`deliberate.failure`) while passing another (`ok.pc`). It exits with code 1 and writes a JSON report. The host test `k3s_failing_pc_fails_test` wraps this execution, asserting that the harness parses the failure line correctly rather than silently passing on malformed reports or raw dump output.

## Key Interfaces
- `main()`: Entry point for the guest test binary that parses flags and runs validation checks.
- `firecracker_k3s_test`: Bazel rule used to launch the VM and execute the guest binary.
- `k3s_failing_pc_fails_test`: Shell test that verifies failure detection logic.

## Dependencies
- `firecracker_k3s_test` infrastructure
- Standard Go flag and JSON libraries
- K3s cluster components (containerd, kubelet)
- Bazel build rules for test execution

## Subcomponents
- `BUILD.bazel`: Defines test targets and dependencies.
- `main.go`: Guest-side test binary implementation.
- `data.txt`: Static payload fixture for file integrity checks.
- `fixture.yaml`: ConfigMap manifest for marker validation.
- `k3s_extras.yaml`: Signal manifest for scenario triggering.
- `failing/`: Directory containing the intentional failure test binary.