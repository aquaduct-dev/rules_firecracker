<!-- docdaemon ts:2026-10-10T19:04:55Z hash:e64b032f28f19ddf model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script generates a Bash wrapper for Firecracker K3s integration tests, orchestrating VM execution, log streaming, and JSON report validation.

### Purpose
`gen_k3s_test.sh` is a code generator that produces an executable shell script (`--out`). This generated script serves as the test runner for `sh_test` targets in Bazel, specifically designed to validate K3s behavior inside a microVM without using traditional expect markers.

### Key Functions
*   **Argument Parsing**: Accepts paths for the output script, the microvm runner binary (via rlocation), timeout duration, and optional jq binary location.
*   **Script Generation**: Emits a self-contained Bash script that:
    1.  Resolves runfiles and sources Bazel utilities.
    2.  Launches the microVM runner with a hard timeout cap.
    3.  Streams serial logs to stderr in real-time via `tail -F`.
    4.  Monitors for `K3S_POWEROFF` signals to handle graceful shutdowns before hitting hard deadlines.
    5.  Extracts JSON reports from the log between `===REPORT_BEGIN===` and `===REPORT_END===` markers.
    6.  Validates the JSON structure and checks `pass_conditions` arrays using `jq`.
    7.  Returns exit code 0 only if all pass conditions are met; otherwise, it prints failures to stderr.

### Integration
This file is part of the Firecracker testing infrastructure. It bridges the gap between the low-level microVM runner and high-level Bazel test expectations by handling the complex lifecycle management and result parsing logic within the generated wrapper scripts.