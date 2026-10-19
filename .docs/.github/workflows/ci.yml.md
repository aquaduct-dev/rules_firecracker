<!-- docdaemon ts:2026-10-19T23:24:28Z hash:94e6eefcabd5d642 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines the GitHub Actions CI pipeline for building, testing, and validating Firecracker-based virtual machines.

The workflow triggers on pushes to `main`, pull requests, and manual dispatches. It uses concurrency groups to cancel redundant runs on the same branch or PR. The pipeline consists of four parallel jobs:

- **unit**: Runs fast feedback checks including Bazel analysis, unit tests, and documentation generation without KVM access.
- **kernel**: Builds the guest kernel (`vmlinux`) from both the root module and the e2e workspace. It caches the result in a disk cache to speed up subsequent jobs, skipping the build if the cache is hit.
- **vm**: Executes all non-manual tests (unit, single-VM boots, failure paths, container, k3s, examples) requiring KVM. It verifies that `firecracker` is not present on the host PATH and uploads test logs on failure.
- **cluster**: Runs multi-VM cluster tests (ping, k3s, persistent disks) using a host bridge with sudo and KVM. Tests run sequentially due to high memory requirements.
- **e2e**: Validates external consumption of the rules by running smoke tests in the `e2e/smoke` directory.

The `kernel` job must complete before `vm`, `cluster`, and `e2e` can start, ensuring the guest image is available. Artifacts are uploaded only when tests fail.