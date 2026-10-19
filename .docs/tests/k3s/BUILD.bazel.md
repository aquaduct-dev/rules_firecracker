<!-- docdaemon ts:2026-10-19T23:24:34Z hash:b73894964f5afcf3 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines the Bazel build targets for the `k3s_extras` integration test, which validates that a Firecracker-based k3s guest correctly handles extra manifests, files, and container images.

The target `k3s_extras_test` uses `firecracker_k3s_test` to spin up a VM with specific extras: it installs a static busybox binary, places `data.txt` at `/etc/fcextra/data.txt`, imports a pre-built OCI image (`fctest-extra.tar`) into containerd, and applies two YAML manifests. The test binary `k3s_extras` verifies these artifacts are present and correct.

To ensure robustness, the file also includes a failing-path test suite. The `inner_failing_pc` target runs a test designed to fail a pass condition. This is wrapped in `k3s_failing_pc_fails_test`, an `sh_test` that expects failure. It checks that the harness reports the specific error line `deliberate.failure	deliberate`, ensuring the test runner correctly parses and reports failures rather than silently passing on malformed reports.