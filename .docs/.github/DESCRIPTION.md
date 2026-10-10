<!-- docdaemon ts:2026-10-10T19:07:04Z hash:523877d1ffa097de model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory configures the CI/CD infrastructure for building, testing, and validating Firecracker Bazel rules.

## Overview
The `.github` directory orchestrates continuous integration through a composite action and a comprehensive workflow definition. The `actions/setup` composite action prepares the Ubuntu runner environment by installing dependencies, configuring KVM access, and setting up Bazelisk with caching to optimize build times. The `workflows/ci.yml` workflow automates the verification pipeline, ensuring code quality and functional correctness across unit, integration, and end-to-end scenarios before merging changes.

## Deep Dive
### Environment Configuration
The `setup` composite action initializes the CI runner for `rules_firecracker`. It installs essential build tools like `build-essential`, `flex`, and `bison`, alongside utilities for disk image manipulation such as `e2fsprogs` and `gdisk`. To support Bazel's `linux-sandbox`, it disables AppArmor restrictions on unprivileged user namespaces if applicable. Additionally, it creates udev rules to grant read/write access to `/dev/kvm`, which is critical for virtual machine-based tests. Bazelisk is configured with repository and persistent disk caching at `~/.cache/fc-disk-cache` to store prebuilt guest kernels, significantly reducing CI latency.

### CI Pipeline Orchestration
The `ci.yml` workflow triggers on pushes to `main`, pull requests, and manual dispatches, enforcing concurrency limits to cancel redundant runs. It executes five parallelizable jobs: **unit** for static analysis and fast feedback without KVM; **kernel** to build the guest Linux kernel (`vmlinux`) and cache the artifact; **vm** for single-VM boots and failure path tests requiring KVM; **cluster** for multi-VM rig tests like k3s clusters, which require sudo privileges and run sequentially due to high memory usage; and **e2e** to validate rule consumption as an external module. This structure ensures comprehensive validation while optimizing resource utilization.

## Key Interfaces
- Composite Action Input: `kvm` (boolean, default: true) - Controls KVM configuration
- Workflow Triggers: push, pull_request, workflow_dispatch
- Job Dependencies: kernel -> vm/cluster
- Artifact Caching: Content-based key for guest kernel disk images
- Concurrency Group: Branch/PR level cancellation of redundant runs

## Dependencies
- GitHub Actions runner environment (Ubuntu 24.04)
- bazel-contrib/setup-bazel
- Build dependencies: build-essential, flex, bison, e2fsprogs, gdisk
- KVM-enabled hosts for vm and cluster jobs
- Sudo privileges for cluster job network setup
- Bazel build system

## Subcomponents
- actions/setup/action.yml
- workflows/ci.yml