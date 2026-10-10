<!-- docdaemon ts:2026-10-10T19:07:21Z hash:e17d80b7ade6a164 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory serves as the root workspace for `rules_firecracker`, defining the Bazel module, licensing, and CI/CD infrastructure.

## Overview
It orchestrates the build system configuration, dependency management, and continuous integration pipelines for Firecracker microVM rules. The directory ensures hermetic builds by pinning external binaries and kernels while exposing public APIs through standardized Bazel targets. It acts as the entry point for consumers to integrate microVM capabilities into their own workspaces.

## Deep Dive
### Module and Build Configuration
The `MODULE.bazel` file declares the `rules_firecracker` module and its dependencies, including `bazel_skylib` and `rules_shell`. It pins critical external assets like the Firecracker VMM binary, Linux kernel source, Busybox, and k3s to ensure reproducible, hermetic builds. This approach eliminates host-specific variations by fetching pre-built or source-pinned artifacts directly from official releases.

### CI/CD Orchestration
The `.github` directory configures the continuous integration environment using GitHub Actions. A composite action sets up the Ubuntu runner with necessary build tools, KVM access, and Bazelisk caching to optimize build times. The main workflow automates verification across unit, kernel, VM, cluster, and end-to-end jobs, enforcing concurrency limits and ensuring code quality before merges.

### Documentation and Licensing
The root `BUILD.bazel` exports the `LICENSE` file, making legal terms accessible to all consumers via Bazel's export mechanism. The `README.md` provides usage instructions for macros like `firecracker_initramfs` and `firecracker_test`. Automated documentation generation in the `docs/` subdirectory keeps API references synchronized with the codebase using Stardoc.

## Key Interfaces
- `//firecracker:defs.bzl`: Public Starlark macros for defining microVMs, containers, and tests.
- `@rules_firecracker//:firecracker`: Alias for the platform-specific Firecracker binary.
- `@rules_firecracker//:vmlinux`: Pinned Linux 6.1.155 kernel binary.
- Composite Action Input: `kvm` (boolean) - Controls KVM configuration in CI runners.
- Workflow Triggers: push, pull_request, workflow_dispatch.

## Dependencies
- GitHub Actions runner environment (Ubuntu 24.04)
- bazel-contrib/setup-bazel
- Build dependencies: build-essential, flex, bison, e2fsprogs, gdisk
- KVM-enabled hosts for vm and cluster jobs
- Sudo privileges for cluster job network setup
- Bazel build system

## Subcomponents
- .github/actions/setup/action.yml
- .github/workflows/ci.yml
- BUILD.bazel
- LICENSE
- MODULE.bazel
- README.md
- docs/
- e2e/
- examples/
- firecracker/
- tests/