<!-- docdaemon ts:2026-10-19T23:25:26Z hash:01f397af05b07448 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory configures the CI runner environment and defines the GitHub Actions workflows for building, testing, and validating Firecracker-based virtual machines.

## Overview
The `.github` directory orchestrates the continuous integration pipeline for Firecracker development. It ensures that GitHub Actions runners are properly configured with necessary build tools, KVM permissions, and Bazel caching before executing tests. The workflow validates code integrity through unit tests, compiles guest kernels, and verifies VM execution in single-node and cluster scenarios. This setup guarantees that both internal development and external consumption of Firecracker rules function correctly.

## Deep Dive
### Host Dependencies
Installs `build-essential`, kernel headers (`libelf-dev`, `libssl-dev`), and filesystem utilities (`e2fsprogs`, `gdisk`) required for building guest kernels and images.

### Bazel Sandbox Configuration
Disables `apparmor_restrict_unprivileged_userns` if present to allow Bazel's linux-sandbox to function correctly on Ubuntu 24.04 runners.

### KVM Access Control
Creates a udev rule (`99-kvm4all.rules`) to set `/dev/kvm` permissions to `0666`. The action reloads rules, triggers them with `--settle` to ensure application, and verifies read/write access immediately to fail fast if configuration fails. This prevents silent failures during VM tests due to permission issues.

### Build System Setup
Uses `bazel-contrib/setup-bazel` to install Bazelisk. It enables repository and disk caching at `/home/runner/.cache/fc-disk-cache` and sets common flags for color output and progress reporting.

### Kernel Caching
Restores the prebuilt guest kernel from the disk cache using a key derived from `.bazelversion`, `MODULE.bazel`, and kernel-specific build scripts/configs. This avoids rebuilding the kernel (~10-15 mins) unless source files change.

### Workflow Orchestration
The `ci.yml` workflow triggers on pushes to `main`, pull requests, and manual dispatches. Concurrency groups cancel redundant runs on the same branch or PR to save resources. Pushes to main and PRs are handled distinctly to avoid duplicate executions for the same commit.

### Unit Testing
The `unit` job provides fast feedback by running Bazel analysis, unit tests, and documentation generation without KVM access, ensuring basic code integrity and build rules are validated early.

### Kernel Building
The `kernel` job builds the guest kernel (`vmlinux`) from both the root module and the e2e workspace. Results are cached in a disk cache to accelerate subsequent jobs, acting as a prerequisite for `vm`, `cluster`, and `e2e` jobs.

### VM and Cluster Testing
The `vm` job executes non-manual tests, including single-VM boots, failure paths, container, k3s, and examples. It requires KVM and verifies that `firecracker` is not present on the host PATH, relying instead on pinned binaries resolved through runfiles. The `cluster` job runs multi-VM tests (ping, k3s, persistent disks) using a host bridge with sudo and KVM. Due to high memory requirements, these tests run sequentially rather than in parallel.

### E2E Validation
The `e2e` job validates external consumption of the rules by running smoke tests in the `e2e/smoke` directory, ensuring that the public API and rules behave correctly when used outside the internal development environment.

### Artifact Management
Artifacts are uploaded only when tests fail, reducing storage overhead and keeping successful runs clean. Recent changes ensure guest images have root-owned files to address cleanup issues in docdaemon.

## Key Interfaces
*   **Inputs**: `kvm` (default: `true`) to enable KVM permission setup.
*   **Outputs**: `kernel-cache-hit` indicating if the kernel cache was restored successfully.
*   **Workflow Triggers**: `push`, `pull_request`, `workflow_dispatch`
*   **Jobs**: `unit`, `kernel`, `vm`, `cluster`, `e2e`
*   **Artifacts**: Uploaded on failure for debugging

## Dependencies
*   GitHub Actions runner environment
*   Bazel build system
*   KVM hardware support
*   Pinned Firecracker v1.17.0 binaries
*   Disk caching mechanisms
*   `bazel-contrib/setup-bazel`
*   `build-essential`
*   `libelf-dev`
*   `libssl-dev`
*   `e2fsprogs`
*   `gdisk`

## Subcomponents
*   actions/
*   workflows/