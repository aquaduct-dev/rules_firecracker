<!-- docdaemon ts:2026-10-19T23:25:02Z hash:3f873ad9c1092191 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory implements a static Go binary and associated Bazel targets to verify k3s cluster readiness inside a Firecracker microVM.

## Overview
The `k3s_smoke` suite validates that a single-node Kubernetes cluster boots correctly within a minimal root filesystem. It distinguishes between unit tests for parsing logic and integration tests that boot a full VM, ensuring both code correctness and end-to-end functionality. The design prioritizes static linking to support execution in environments lacking standard C libraries.

## Deep Dive
### Guest Binary Logic
The `main.go` binary runs inside the guest after `k3s` initializes. It performs two critical checks: verifying the existence of `/etc/rancher/k3s/k3s.yaml` and polling `kubectl get nodes` until a node reports `Ready=True`. The implementation uses `strings.Cut` for efficient parsing of tab-separated node status output, handling edge cases like empty lines or malformed data without external dependencies. Diagnostic reports are written as JSON before exit, capturing cumulative failure counts to distinguish transient network issues from configuration errors.

### Build Configuration
The `BUILD.bazel` file defines three primary targets. `k3s_smoke_lib` compiles the shared source, while `k3s_smoke` produces a statically linked binary. Static linking is mandatory because the embedded rootfs contains only busybox and k3s, lacking a C library. This avoids explicit `cgo=0` flags by leveraging `rules_go` defaults. The `k3s_smoke_test` target orchestrates an end-to-end scenario using a custom `firecracker_k3s_test` rule, which boots a microVM and executes the binary. It is tagged `requires-kvm` to skip on hosts without hardware virtualization.

### Unit Testing
`main_test.go` isolates the `hasReady` function, validating its ability to parse `kubectl` output formats. These tests run without booting a VM, providing rapid feedback on parsing logic changes. Recent updates replaced hand-written splitting logic with `strings.Split` and `strings.Cut` to ensure consistent behavior across various input formats, including trailing newlines and blank lines.

## Key Interfaces
- `waitNodeReady`: Polls kubectl until timeout, distinguishing API failures from unready states.
- `hasReady`: Parses tab-separated node output to detect any node with status `True`.
- `writeReport`: Serializes diagnostic data to JSON for host-side analysis.

## Dependencies
- `rules_go`: For Go compilation and static linking.
- `firecracker`: Pinned v1.17.0 binaries for microVM orchestration.
- `k3s`: Embedded in the guest rootfs.

## Subcomponents
- `main.go`: Guest-side smoke test binary.
- `main_test.go`: Unit tests for node status parsing.
- `BUILD.bazel`: Bazel build definitions for library, binary, and tests.