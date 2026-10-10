<!-- docdaemon ts:2026-10-10T19:05:46Z hash:8932a61a41785765 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory defines the CI pipeline for building, testing, and validating Firecracker rules across unit, integration, and end-to-end scenarios.

## Overview
The `ci.yml` workflow automates the verification of Bazel rules for Firecracker, ensuring code quality and functional correctness before merging. It triggers on pushes to `main`, pull requests, and manual dispatches, enforcing concurrency limits to cancel redundant runs on the same branch or PR. The pipeline is structured into parallelizable jobs that depend on a shared kernel build artifact to optimize execution time.

## Deep Dive
The workflow orchestrates five distinct jobs to cover the full spectrum of validation:

### Static Analysis and Unit Tests
The **unit** job provides fast feedback by running static analysis, unit tests, and documentation generation. It operates without KVM access, making it lightweight and suitable for early-stage checks.

### Kernel Build
The **kernel** job builds the guest Linux kernel (`vmlinux`) from both the root module and the e2e workspace perspectives. It caches the resulting disk image in `~/.cache/fc-disk-cache` using a content-based key to accelerate downstream jobs that require the kernel binary.

### VM Integration Tests
The **vm** job executes non-manual tests, including single-VM boots, failure paths, container support, k3s single-node setups, and examples. It requires KVM and depends on the successful completion of the `kernel` job. Test logs are uploaded as artifacts upon failure for debugging.

### Cluster Rig Tests
The **cluster** job runs multi-VM rig tests, such as 2-VM ping, 3-node k3s clusters, and persistent disk operations, on a host bridge. These tests require elevated privileges (`sudo`) and KVM. Due to high memory usage, they run sequentially with `--local_test_jobs=1`. Logs are uploaded on failure.

### End-to-End Validation
The **e2e** job validates the rules when consumed as an external module via `local_path_override`. This mirrors how users and the BCR test module interact with the codebase, ensuring compatibility in real-world consumption scenarios.

## Key Interfaces
- Workflow trigger events (push, pull_request, workflow_dispatch)
- Job dependencies (kernel -> vm/cluster)
- Artifact caching strategy (content-based key for disk images)
- Concurrency group configuration (branch/PR level)

## Dependencies
- GitHub Actions runner environment
- KVM-enabled hosts for vm and cluster jobs
- Sudo privileges for cluster job network setup
- Bazel build system for rule compilation and testing

## Subcomponents
- ci.yml