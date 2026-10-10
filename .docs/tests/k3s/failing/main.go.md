<!-- docdaemon ts:2026-10-10T19:05:00Z hash:e3921e7cdd592d66 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file implements a guest test binary designed to simulate a specific test failure scenario for validating the K3s test harness.

## Purpose
The `failing` command serves as a controlled failure injection tool within the `firecracker_k3s_test` suite. Its primary role is to verify that the test framework correctly detects and reports when a pass condition fails, ensuring the integrity of the assertion logic in `//tests/k3s:k3s_failing_pc_fails_test`.

## Key Behaviors
- **JSON Report Generation**: Upon execution, the program writes a JSON payload to `/tmp/report.json` (configurable via `-report-json`). This payload defines two pass conditions:
  - `ok.pc`: A condition marked as passed.
  - `deliberate.failure`: A condition explicitly marked as failed with an error message ("this PC always fails").
- **Exit Code**: The process exits with code `1`, signaling a failure state to the host environment regardless of the report content.

## Integration
This binary is consumed by the K3s integration tests running on Firecracker microVMs. It allows developers to assert that the test runner properly interprets negative outcomes from guest agents, distinguishing between actual infrastructure issues and expected test failures.