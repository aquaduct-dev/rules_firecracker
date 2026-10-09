<!-- docdaemon ts:2026-10-09T22:28:53Z hash:9e524fe8818f5cc2 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script generates a Bash wrapper for K3s microVM tests, handling VM lifecycle, log streaming, and JSON report validation.

### Purpose
`gen_k3s_test.sh` is a code generator that produces an executable `sh_test` script. Unlike standard test generators, it does not use expect markers; instead, it parses structured JSON reports emitted by the guest binary between specific delimiters to determine pass/fail status.

### Key Functions
- **Argument Parsing**: Accepts `--out`, `--runner-rloc`, and `--timeout` to configure the generated test.
- **Template Generation**: Outputs a self-contained Bash script that:
  - Resolves Bazel runfiles and sources the `runfiles.bash` helper.
  - Launches the microVM runner with a hard timeout cap using `setsid`.
  - Streams serial logs to stderr in real-time via `tail -F`.
  - Implements a grace period after detecting `K3S_POWEROFF` before force-killing the VM.
  - Extracts the JSON payload from the log file, sanitizes it (stripping CR/LF and non-JSON prefixes), and validates it using `jq`.
  - Checks `pass_conditions` in the report; exits non-zero if any condition failed or is missing.
  - Mirrors the report to `SCENARIO_REPORT_PATH` if writable, otherwise relies on Bazel undeclared outputs.

### Integration
This file is part of the Firecracker testing infrastructure. It bridges Bazel's build system with custom K3s integration tests, ensuring consistent execution environments and reliable result reporting across sandboxed builds.