<!-- docdaemon ts:2026-10-10T19:04:55Z hash:0d5204915be539cf model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script generates a self-contained shell test that boots a Firecracker microVM, monitors its serial output for expected markers to enable early exit, and asserts the presence or absence of specific log strings.

### Purpose
`gen_test.sh` is a code generator used in the build system to produce executable smoke-test scripts. It abstracts away the boilerplate required to run a microVM with proper resource management, timeout handling, and log verification.

### Key Functions
*   **Argument Parsing**: Accepts configuration for the output path, runner binary location (Rlocation), boot timeout, and lists of `--expect` (must appear) and `--unexpect` (must not appear) markers.
*   **Script Generation**: Emits a bash script that:
    *   Resolves the runner binary via Bazel runfiles.
    *   Launches the microVM in a new session (`setsid`) to allow process-tree killing.
    *   Streams logs to stderr for live visibility while capturing them to a temp file.
    *   Implements an **early-exit loop** that kills the VM as soon as all `--expect` markers are found, significantly reducing wall-clock time compared to waiting for the full timeout.
    *   Enforces a hard deadline if markers never arrive.
    *   Performs final assertions on the captured log file before exiting with status 0 or 1.

### Integration
This tool is invoked by the build system to create individual test targets. The generated scripts are designed to be robust against hanging processes and provide immediate feedback on boot success or failure based on serial console output.