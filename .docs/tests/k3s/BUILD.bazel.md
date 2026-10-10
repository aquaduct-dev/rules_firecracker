<!-- docdaemon ts:2026-10-10T19:04:59Z hash:d45191241f401a4d model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines Bazel build targets to test K3s functionality within a Firecracker VM, including extra resource injection and failure scenario validation.

It sets up a Go binary (`k3s_extras`) that verifies the guest environment by checking applied manifests, installed files, and imported container images. The `firecracker_k3s_test` target `k3s_extras_test` exercises these features using `extra_execs`, `extra_files`, `extra_images`, and `extra_manifests`.

An OCI image is constructed from a single layer containing `data.txt`, loaded into the local registry as `fctest/extra:latest`, and packaged as a tarball for injection into the VM. This ensures the test binary can verify that external resources are correctly accessible inside the isolated environment.

The file also includes a failing path test suite. A separate Go binary (`failing`) is used in the `inner_failing_pc` test scenario, tagged as manual. An accompanying shell test (`k3s_failing_pc_fails_test`) expects this scenario to fail with the specific error message "deliberate.failure", ensuring that pass condition failures are correctly detected and reported.