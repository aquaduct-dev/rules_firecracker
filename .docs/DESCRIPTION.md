<!-- docdaemon ts:2026-10-15T22:45:22Z hash:26a5f03ec115a9eb model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This repository root defines the `rules_firecracker` Bazel module for booting Linux microVMs in tests.

## Overview
The root directory serves as the entry point for the `rules_firecracker` project, a Bazel extension that enables developers to define, build, and run isolated Firecracker microVMs within their test suites. It orchestrates the entire development lifecycle by exposing public APIs, managing pinned dependencies for hermetic builds, and configuring continuous integration pipelines. By centralizing license exports and module definitions, it ensures that consumers can easily integrate VM-based testing into their existing Bazel workspaces while maintaining compliance and reproducibility.

## Deep Dive
### Module Configuration
The `MODULE.bazel` file declares the `rules_firecracker` module and its core dependencies, including `bazel_skylib` and `rules_shell`. To guarantee hermetic builds, it pins critical external binaries such as the Firecracker VMM (v1.17.0), jq, k3s, and a static Busybox initramfs base. These assets are fetched via `http_archive` with verified checksums, eliminating the need for host-installed tools during guest image construction or execution.

### Build System Entry Point
The root `BUILD.bazel` file acts as the workspace's primary build target, primarily responsible for exporting the `LICENSE` file. This standard Bazel practice ensures that any artifact built within the workspace correctly attributes legal terms, making the license accessible to downstream consumers without requiring internal path knowledge.

### CI/CD Orchestration
The `.github` directory automates the verification pipeline through GitHub Actions. The `setup` composite action prepares Ubuntu runners by installing build essentials, configuring KVM access via udev rules, and setting up Bazelisk caching to optimize kernel build times. The `ci.yml` workflow enforces concurrency limits and runs parallel jobs for unit analysis, kernel building, single-VM validation, multi-node cluster testing, and end-to-end rule consumption checks.

### Documentation Automation
The `docs` directory maintains API reference consistency using Stardoc. A dedicated Bazel target parses `//firecracker:defs.bzl` to generate Markdown documentation, which is then synchronized to `docs/defs.md`. A corresponding test ensures committed docs match generated output, preventing documentation drift in the main branch.

## Key Interfaces
- `MODULE.bazel`: Module declaration and dependency pinning
- `BUILD.bazel`: Root build target and license export
- `.github/actions/setup`: Composite action for runner environment setup
- `.github/workflows/ci.yml`: CI workflow definition
- `docs/BUILD.bazel`: Documentation generation targets

## Dependencies
- Bazel Build System
- GitHub Actions Runner Environment (Ubuntu 24.04)
- bazel-contrib/setup-bazel
- Host toolchain for kernel compilation
- KVM-enabled hosts for integration tests

## Subcomponents
- .github/
- docs/
- e2e/
- examples/
- firecracker/
- tests/
- BUILD.bazel
- LICENSE
- MODULE.bazel
- README.md