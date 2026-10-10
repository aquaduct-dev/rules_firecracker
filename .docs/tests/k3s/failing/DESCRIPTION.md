<!-- docdaemon ts:2026-10-10T19:05:32Z hash:037ee0e81dcda87e model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains a guest test binary designed to simulate specific failure scenarios for validating the K3s test harness.

## Overview
The `failing` command serves as a controlled failure injection tool within the `firecracker_k3s_test` suite. Its primary role is to verify that the test framework correctly detects and reports when a pass condition fails, ensuring the integrity of the assertion logic in `//tests/k3s:k3s_failing_pc_fails_test`. By simulating negative outcomes, it allows developers to distinguish between actual infrastructure issues and expected test failures.

## Deep Dive

### Controlled Failure Injection
The binary is engineered to produce predictable errors rather than random crashes. It generates a JSON report containing two distinct pass conditions: one marked as passed (`ok.pc`) and another explicitly marked as failed (`deliberate.failure`). This dual-state output ensures the test runner processes both success and failure signals correctly.

### Report Generation
Upon execution, the program writes a JSON payload to `/tmp/report.json`, with the path configurable via the `-report-json` flag. The payload structure defines the status of each pass condition, including error messages for failures. This standardized format allows the host environment to parse and validate the guest's state accurately.

### Exit Code Signaling
Regardless of the report content, the process exits with code `1`. This explicit failure signal ensures that the host environment immediately recognizes the test as unsuccessful, triggering appropriate logging and reporting mechanisms within the integration test suite.

## Key Interfaces
- None (internal implementation details only)

## Dependencies
- Standard Go libraries for JSON marshaling and file I/O
- Firecracker microVM runtime environment

## Subcomponents
- main.go