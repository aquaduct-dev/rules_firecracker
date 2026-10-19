<!-- docdaemon ts:2026-10-19T23:24:43Z hash:cc40ff73e3fbf5bf model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains a guest test binary designed to intentionally fail specific pass conditions, allowing the host test suite to verify that failures are correctly detected and reported.

## Overview
The `failing` command serves as a negative test case for the `firecracker_k3s_test` infrastructure. By guaranteeing a failure, it ensures the launcher properly propagates test results back to the CI system. This binary is used by `//tests/k3s:n3s_failing_pc_fails_test` to assert that the framework correctly identifies and handles failing pass conditions.

## Deep Dive
### Flag Handling
The binary accepts several flags (`scenario`, `kubeconfig`, `namespace`) solely to satisfy the launcher's contract. These are ignored internally because `flag.Parse` will exit with code 2 if any undefined flags are passed, preventing partial report generation. This strict adherence ensures compatibility with the host orchestrator without introducing side effects from unused parameters.

### Report Generation
It writes a JSON report to `/tmp/report.json` (default). This report defines two pass conditions:
- `ok.pc`: Marked as passed.
- `deliberate.failure`: Marked as failed with an error message.

This dual-condition approach allows the test suite to verify both successful reporting paths and failure detection mechanisms within the same execution context. The deliberate failure ensures that the CI pipeline captures and reports errors accurately, rather than silently passing or masking issues.

### Exit Code
The process always exits with status `1`, signaling a test failure to the orchestrator. This explicit exit code is critical for the host test runner to distinguish between intentional test failures and unexpected crashes or timeouts. It provides a clear signal that the negative test case has executed as expected, confirming the robustness of the failure handling logic in the broader testing framework.

## Key Interfaces
- `main()`: Entry point that parses flags, generates the report, and exits with code 1.

## Dependencies
- Standard Go flag package for argument parsing.
- JSON encoding/decoding libraries for report generation.
- `firecracker_k3s_test` infrastructure for integration.

## Subcomponents
- `main.go`: The guest test binary implementation.