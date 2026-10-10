<!-- docdaemon ts:2026-10-10T19:05:17Z hash:aab93c83f34d32ee model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script unit tests the `gen_k3s_test` generator to verify report extraction, pass condition evaluation, and failure handling.

### Purpose
Validates the behavior of `firecracker/gen_k3s_test` by simulating runner outputs and checking exit codes, output files, and error messages.

### Key Components
- **`report_runner`**: Generates a fake runner script containing JSON pass conditions wrapped in `===REPORT_BEGIN/END===` markers.
- **`run`**: Executes the generated test script (`t.sh`) with controlled environment variables (e.g., `RUNFILES_DIR`, `SCENARIO_REPORT_PATH`) and captures the exit code.
- **Test Cases**:
  - Verifies success when all pass conditions are true.
  - Checks failure and error message inclusion when a condition fails.
  - Ensures failure for empty or missing pass conditions.
  - Validates strict type checking for the `passed` field (rejects strings).
  - Confirms handling of malformed JSON and missing report markers.