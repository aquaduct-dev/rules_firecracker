<!-- docdaemon ts:2026-10-30T02:12:56Z hash:8395edcc0bd72bcd model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains the integration test suite for running K3s on Firecracker, validating cluster functionality, network routing, and failure handling.

## Overview
The `tests/k3s` directory defines Bazel targets to build and execute integration tests against a K3s guest VM. It verifies that the guest kernel supports necessary netfilter options for kube-proxy, validates the injection of extra files, executables, and container images, and ensures the test harness correctly reports both success and intentional failures.

## Deep Dive
### Feature Validation
The primary test target injects static binaries, files, and OCI images into the VM before booting K3s. It verifies that `containerd` auto-imports local images without registry access and that injected ConfigMaps are accessible. A critical check ensures ClusterIP services are routable, relying on specific netfilter kernel modules (comment, mark, statistic) enabled to support kube-proxy’s iptables rules.

### Negative Testing
A dedicated subdirectory provides a guest binary designed to fail specific pass conditions. This allows the host suite to verify that the launcher correctly propagates failure states and parses JSON reports accurately, ensuring CI pipelines catch errors rather than masking them as silent passes.

### Test Fixtures
Static YAML manifests define expected cluster state, such as a ConfigMap marker used to validate manifest application. A raw data file serves as a deterministic payload for integrity checks, ensuring that file ownership and permissions are correctly set within the guest rootfs.

## Key Interfaces
- `k3s_extras_test`: Bazel target for the main feature validation suite.
- `k3s_failing_pc_fails_test`: Bazel target for negative testing failure reporting.
- `main.go`: Guest-side binary orchestrating flag, manifest, and network checks.
- `failing/main.go`: Guest binary intentionally failing to test error propagation.

## Dependencies
- `//firecracker:defs.bzl`: Firecracker-specific Bazel rules.
- Standard Go libraries for JSON parsing and HTTP networking.
- K3s and containerd binaries within the guest environment.

## Subcomponents
- `BUILD.bazel`: Bazel target definitions.
- `data.txt`: Static test payload.
- `fixture.yaml`: Expected ConfigMap manifest.
- `k3s_extras.yaml`: Scenario file for flag verification.
- `main.go`: Main guest test logic.
- `failing/`: Directory containing the failure-intentional binary.