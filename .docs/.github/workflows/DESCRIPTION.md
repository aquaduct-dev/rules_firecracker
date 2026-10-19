<!-- docdaemon ts:2026-10-19T23:25:04Z hash:c428ddf61a5520ea model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory defines the GitHub Actions CI pipeline for building, testing, and validating Firecracker-based virtual machines.

## Overview
The `ci.yml` workflow orchestrates a comprehensive test suite covering unit validation, kernel compilation, single-VM execution, and multi-VM cluster scenarios. It ensures that guest images are built once and cached efficiently before downstream jobs consume them. The pipeline is designed to fail fast on unit tests while providing robust verification of KVM-dependent features through parallelized and sequential job stages.

## Deep Dive
### Concurrency and Triggers
The workflow triggers on pushes to `main`, pull requests, and manual dispatches. Concurrency groups cancel redundant runs on the same branch or PR to save resources. Pushes to main and PRs are handled distinctly to avoid duplicate executions for the same commit.

### Unit Testing (`unit`)
This job provides fast feedback by running Bazel analysis, unit tests, and documentation generation. It operates without KVM access, ensuring that basic code integrity and build rules are validated early in the pipeline.

### Kernel Building (`kernel`)
The `kernel` job builds the guest kernel (`vmlinux`) from both the root module and the e2e workspace. Results are cached in a disk cache to accelerate subsequent jobs. This job acts as a prerequisite for `vm`, `cluster`, and `e2e` jobs, ensuring the guest image is available before integration tests run.

### VM and Cluster Testing (`vm`, `cluster`)
The `vm` job executes non-manual tests, including unit tests, single-VM boots, failure paths, container, k3s, and examples. It requires KVM and verifies that `firecracker` is not present on the host PATH, relying instead on pinned binaries resolved through runfiles. Test logs are uploaded only on failure.

The `cluster` job runs multi-VM tests (ping, k3s, persistent disks) using a host bridge with sudo and KVM. Due to high memory requirements, these tests run sequentially rather than in parallel.

### E2E Validation (`e2e`)
The `e2e` job validates external consumption of the rules by running smoke tests in the `e2e/smoke` directory. This ensures that the public API and rules behave correctly when used outside the internal development environment.

### Artifact Management
Artifacts are uploaded only when tests fail, reducing storage overhead and keeping successful runs clean. Recent changes ensure guest images have root-owned files to address cleanup issues in docdaemon.

## Key Interfaces
- Workflow triggers: `push`, `pull_request`, `workflow_dispatch`
- Jobs: `unit`, `kernel`, `vm`, `cluster`, `e2e`
- Artifacts: Uploaded on failure for debugging

## Dependencies
- GitHub Actions runner environment
- Bazel build system
- KVM hardware support
- Pinned Firecracker v1.17.0 binaries
- Disk caching mechanisms

## Subcomponents
- ci.yml