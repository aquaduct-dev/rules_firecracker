<!-- docdaemon ts:2026-10-09T22:29:07Z hash:fe5d825376d28130 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains the build configuration and source code for a Go-based smoke test agent that validates k3s cluster health within a Firecracker microVM.

## Overview
The `k3s_smoke` package provides the guest-side binary responsible for verifying that a single-node k3s server is operational inside a microVM environment. It serves as the execution target for the `firecracker_k3s_test`, ensuring that critical infrastructure components like kubeconfig availability and node readiness are functioning correctly before the test harness considers the boot process successful. By statically linking against a minimal busybox rootfs, it ensures compatibility with resource-constrained virtual machines while providing structured JSON reports to the host-side harness.

## Deep Dive

### Build Configuration
The `BUILD.bazel` file defines three primary targets: `k3s_smoke_lib` for internal compilation, `k3s_smoke` for the static binary artifact, and `k3s_smoke_test` which orchestrates the Firecracker VM lifecycle. The test target attaches the compiled binary to the VM and enforces a 300-second timeout to accommodate slow startup times in constrained environments. Hosts lacking KVM support can exclude this test using tag filters, allowing CI pipelines to run on non-virtualization-capable hardware.

### Guest-Side Validation Logic
The `main.go` entry point performs two critical assertions after the VM boots. First, it verifies the existence of the kubeconfig file, ensuring the control plane has initialized its state store. Second, it polls the `kubectl` command-line interface every two seconds until at least one node reports a `Ready=True` status. This polling mechanism prevents race conditions where the test might check for readiness before the kubelet has fully registered with the API server.

### Reporting and Integration
Upon completion, the binary serializes a `report` struct containing pass/fail statuses for each validation step into `/tmp/report.json`. This structured output allows the host-side harness to parse specific failure modes, such as missing config files versus timed-out node readiness, enabling precise debugging of microVM boot sequences.

## Key Interfaces
*   `main`: Orchestrates the smoke test sequence and exits with appropriate codes.
*   `waitNodeReady`: Polls kubectl output until a ready node is detected or timeout expires.
*   `hasReady`: Parses tab-separated kubectl output to identify node readiness status.
*   `writeReport`: Serializes the test report struct to JSON and writes it to disk.

## Dependencies
*   Bazel rules_go for Go library and binary compilation.
*   Firecracker SDK via `//:defs.bzl` for microVM orchestration.
*   Standard Go libraries for JSON serialization and HTTP/CLI interaction.

## Subcomponents
*   `BUILD.bazel`: Bazel build definitions for library, binary, and test targets.
*   `main.go`: Guest-side test agent implementation and validation logic.