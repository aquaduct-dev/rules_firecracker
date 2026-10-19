<!-- docdaemon ts:2026-10-19T23:24:35Z hash:6161cea4533f4580 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file is a guest test binary designed to intentionally fail a specific pass condition, allowing the host test suite to verify that failures are correctly detected and reported.

## Purpose
The `failing` command serves as a negative test case for the `firecracker_k3s_test` infrastructure. By guaranteeing a failure, it ensures the launcher properly propagates test results back to the CI system.

## Implementation Details
- **Flag Handling**: The binary accepts several flags (`scenario`, `kubeconfig`, `namespace`) solely to satisfy the launcher's contract. These are ignored internally because `flag.Parse` will exit with code 2 if any undefined flags are passed, preventing partial report generation.
- **Report Generation**: It writes a JSON report to `/tmp/report.json` (default). This report defines two pass conditions:
  - `ok.pc`: Marked as passed.
  - `deliberate.failure`: Marked as failed with an error message.
- **Exit Code**: The process always exits with status `1`, signaling a test failure to the orchestrator.

## Context
This binary is used by `//tests/k3s:k3s_failing_pc_fails_test` to assert that the `firecracker_k3s_test` framework correctly identifies and handles failing pass conditions.