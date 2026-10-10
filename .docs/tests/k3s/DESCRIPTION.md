<!-- docdaemon ts:2026-10-10T19:05:58Z hash:e6ee617f960c8488 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains the test harness, fixtures, and guest binaries required to validate K3s functionality within an isolated Firecracker VM environment.

## Overview
The `tests/k3s` suite verifies that K3s correctly handles extra resource injection, including manifests, files, executables, and container images, inside a microVM. It ensures that the host-side Bazel build targets accurately propagate these resources to the guest and that the guest can detect and report their presence. Additionally, it includes failure scenario validation to confirm that the test framework properly detects and reports pass condition failures.

## Deep Dive
### Resource Injection Verification
The primary goal is to validate the `extra_*` attributes of the `firecracker_k3s_test` target. The guest binary (`k3s_extras`) checks for applied ConfigMaps, specific file permissions, executable flags, and imported container images. This ensures that the isolation layer does not strip or modify injected resources.

### Failure Scenario Testing
A separate subdirectory (`failing/`) contains a binary designed to simulate controlled failures. It generates a JSON report with explicit failure conditions and exits with code 1. This allows the test suite to verify that the host environment correctly interprets guest-side failures and logs them appropriately.

### Fixture Management
Static fixtures like `data.txt` and YAML manifests provide deterministic data for tests. These are used to verify content integrity, hash validation, and manifest application without requiring dynamic generation at runtime.

## Key Interfaces
- None (internal implementation details only)

## Dependencies
- Standard Go libraries for JSON marshaling and file I/O
- Firecracker microVM runtime environment
- K3s/Kubectl command-line tools within the guest

## Subcomponents
- main.go: Guest-side test binary logic
- failing/: Directory containing the failure simulation binary
- BUILD.bazel: Bazel build definitions for test targets
- data.txt: Static test payload fixture
- fixture.yaml: ConfigMap fixture for manifest testing
- k3s_extras.yaml: Signal manifest for extra test scenarios