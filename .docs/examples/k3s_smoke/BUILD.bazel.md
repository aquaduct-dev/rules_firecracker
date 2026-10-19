<!-- docdaemon ts:2026-10-19T23:24:28Z hash:0cc9056bd7ad10f5 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This Bazel build file defines the Go library, binary, unit tests, and integration test targets for the k3s smoke test suite.

The `k3s_smoke_lib` target compiles `main.go` into a private Go library, serving as the shared source for both the executable and the test logic. The `k3s_smoke` binary is statically linked by default via `rules_go`, which is necessary because the embedded k3s rootfs contains only busybox and the k3s binary, lacking a standard C library. This static linking avoids the need for explicit `cgo=0` or `linkmode='external'` configurations.

The `k3s_smoke_unit_test` target runs `main_test.go` against the library without booting a VM. This allows rapid validation of parsing logic (such as node readiness checks) in isolation, ensuring correctness before expensive integration tests run.

The `k3s_smoke_test` target utilizes the custom `firecracker_k3s_test` rule to orchestrate an end-to-end scenario. It boots a single-node k3s server inside a Firecracker microVM and executes the `k3s_smoke` binary within the guest. The test asserts that the guest can read the kubeconfig and that `kubectl get nodes` reports a Ready node. It is tagged with `requires-kvm` to ensure it skips on hosts without hardware virtualization support.