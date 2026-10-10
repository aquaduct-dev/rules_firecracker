<!-- docdaemon ts:2026-10-10T19:04:50Z hash:a10f6b0284542b82 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This Bazel build file defines the Go library, binary, and Firecracker test target for a single-node k3s smoke test.

### Purpose
The file orchestrates the build and execution of a smoke test that boots a k3s server inside a Firecracker microVM. It verifies that the guest-side `k3s_smoke` binary can read the kubeconfig and that `kubectl get nodes` reports a Ready node.

### Targets
- **`k3s_smoke_lib`**: A private Go library wrapping `main.go`. It sets the import path for internal referencing.
- **`k3s_smoke`**: A public static Go binary embedded with the library. Static linking is used because the k3s rootfs lacks libc, relying on rules_go's default behavior for cgo-free code.
- **`k3s_smoke_test`**: The primary test target using `firecracker_k3s_test`. It runs the `k3s_smoke` scenario with a 300-second timeout.

### Integration
This file depends on `//firecracker:defs.bzl` for the custom test rule. It is tagged `requires-kvm`, allowing hosts without KVM support to skip execution via `--test_tag_filters=-requires-kvm`.