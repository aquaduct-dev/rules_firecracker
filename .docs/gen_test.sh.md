<!-- docdaemon ts:2026-10-09T22:28:53Z hash:0d5204915be539cf model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script generates a self-contained shell test that boots a Firecracker microVM, monitors its serial output for expected markers to enable early termination, and asserts pass/fail conditions.

### Purpose
`gen_test.sh` is a code generator used in Bazel builds to create `sh_test` scripts dynamically. It abstracts the boilerplate required to run a microVM with timeout handling, log streaming, and marker-based assertion logic.

### Key Functions
- **Argument Parsing**: Accepts `--out`, `--runner-rloc`, `--timeout`, and repeatable `--expect`/`--unexpect` markers via command-line flags.
- **Script Generation**: Writes a new bash script to `--out` that:
  - Resolves the runner binary using Bazel runfiles.
  - Launches the microVM in a new session (`setsid`) to allow process tree killing.
  - Streams logs to stderr for live visibility.
  - Polls the log file for `--expect` markers; if all are found, it kills the VM early to save time.
  - Enforces a hard timeout deadline if markers never appear.
  - Performs final assertions on both expected and unexpected markers after the VM exits.

### Integration
This file is typically invoked by a Bazel rule or macro to produce executable test scripts at build time. The generated tests rely on `bazel_tools/tools/bash/runfiles/runfiles.bash` for resource resolution.