<!-- docdaemon ts:2026-10-09T22:28:52Z hash:a64beae3d295d960 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This Bazel build file defines the Go library, binary, and Firecracker test target for the k3s smoke test.

The file orchestrates the build artifacts required to validate a single-node k3s server running inside a Firecracker microVM. It loads `firecracker_k3s_test` from `//:defs.bzl` alongside standard Go rules.

### Targets

*   **`k3s_smoke_lib`**: A private `go_library` compiling `main.go`. It sets the import path for internal package references.
*   **`k3s_smoke`**: A public `go_binary` embedding the library. It produces a static binary compatible with the minimal k3s rootfs (busybox + k3s), leveraging rules_go's default static linking for cgo-free code.
*   **`k3s_smoke_test`**: The primary test target using `firecracker_k3s_test`. It configures the `k3s_smoke` scenario, attaches the test binary, and sets a 300-second timeout.

### Execution

Run the test on hosts with KVM support:
```bash
bazel test --config=kvm //k3s_smoke:k3s_smoke_test
```

Hosts without KVM can skip this test by filtering tags:
```bash
bazel test --test_tag_filters=-requires-kvm //k3s_smoke:k3s_smoke_test
```