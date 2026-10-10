<!-- docdaemon ts:2026-10-10T19:05:46Z hash:c160c86f158c597d model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory implements a smoke test that boots a single-node k3s cluster inside a Firecracker microVM and verifies its operational readiness.

## Overview
The `k3s_smoke` directory provides the infrastructure to validate that a k3s server initializes correctly within a lightweight, isolated environment. It combines a Bazel build configuration with a Go binary designed to run inside the guest VM. The primary goal is to ensure that the kubeconfig is accessible and that at least one node reports a `Ready` status, serving as a critical health check in the CI pipeline.

## Deep Dive
### Build Configuration
The `BUILD.bazel` file defines three targets: a private Go library (`k3s_smoke_lib`), a static Go binary (`k3s_smoke`), and a custom test target (`k3s_smoke_test`). Static linking is enforced because the minimal busybox rootfs lacks libc. The test target utilizes `firecracker_k3s_test` from `//firecracker:defs.bzl` and includes a 300-second timeout. It is tagged `requires-kvm`, allowing hosts without KVM support to skip execution via `--test_tag_filters=-requires-kvm`.

### Guest-Side Validation
The `main.go` binary executes inside the microVM after k3s initialization. It orchestrates two main checks: verifying the existence of the kubeconfig file and polling for node readiness. The `waitNodeReady` function retries every 2 seconds using `kubectl get nodes` until a node reports `Ready=True` or a 60-second timeout expires. Results are serialized into a JSON report written to `/tmp/report.json`, enabling automated harnesses to determine success or failure based on pass conditions.

## Key Interfaces
- `k3s_smoke`: Public static Go binary embedded with the library.
- `k3s_smoke_lib`: Private Go library wrapping `main.go` for internal referencing.
- `k3s_smoke_test`: Primary test target running the scenario with a 300-second timeout.
- `reportPC`: Struct representing a single Pass Condition with ID, label, status, and error message.
- `report`: Top-level structure containing the scenario name and list of pass conditions.

## Dependencies
- `//firecracker:defs.bzl`: Custom test rule definitions.
- `rules_go`: Go build rules for static linking.
- `k3s`: The Kubernetes distribution being tested.
- `kubectl`: Command-line tool used for node verification.

## Subcomponents
- `BUILD.bazel`: Bazel build configuration.
- `main.go`: Guest-side validation logic.