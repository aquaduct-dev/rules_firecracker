<!-- docdaemon ts:2026-10-30T02:12:48Z hash:d8c011259638c734 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines Bazel targets to build and run integration tests for k3s on Firecracker, including extra feature validation and failure path verification.

It loads `firecracker_k3s_test` from `//firecracker:defs.bzl` alongside standard Go, OCI, and shell test rules. The primary target, `k3s_extras_test`, validates that the guest kernel supports netfilter options required by kube-proxy for ClusterIP routing, a fix necessitated by earlier kernel configuration gaps. It achieves this by injecting static binaries (`extra_execs`), files (`extra_files`), container images (`extra_images`), and Kubernetes manifests (`extra_manifests`) into the VM before running the `k3s_extras` Go binary.

The file also constructs a minimal OCI image (`image_layer`, `image`, `image_load`, `image_tarball`) containing `data.txt` to verify image import into k3s' containerd.

For negative testing, `inner_failing_pc` runs a failing Go binary under the `failing` scenario. The `k3s_failing_pc_fails_test` shell script verifies that the harness correctly reports this failure, specifically checking for the parsed "deliberate.failure" line in the report output rather than just the raw ID, ensuring robustness against JSON parsing errors.