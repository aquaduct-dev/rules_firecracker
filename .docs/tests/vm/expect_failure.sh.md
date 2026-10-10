<!-- docdaemon ts:2026-10-10T19:05:24Z hash:afd7696ae2444c29 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script wraps an inner test to assert that it fails with a specific diagnostic message within a time limit.

### Purpose
`expect_failure.sh` is a wrapper used in Bazel test suites to verify negative test cases. It executes a target script specified by `INNER_RLOC` and ensures the execution results in a non-zero exit code, contains a required substring in its output (`WANT`), and completes within an optional maximum duration (`MAX_SECONDS`).

### Key Behaviors
- **Execution**: Locates the inner test using `rlocation` and runs it, capturing both stdout and stderr into a temporary file.
- **Failure Assertions**: The wrapper exits with status 1 if:
  - The inner test succeeds (exit code 0).
  - The expected diagnostic string (`WANT`) is missing from the output.
  - The execution time exceeds `MAX_SECONDS`.
- **Output**: Prints the captured output of the inner test to stdout for debugging purposes. Diagnostic messages are printed to stderr.

### Integration
This file is part of the `tests/vm/` directory and relies on Bazel's runfiles mechanism (`RUNFILES_DIR` or `TEST_SRCDIR`). It is designed to be called as a test rule where the environment variables `INNER_RLOC`, `WANT`, and optionally `MAX_SECONDS` are injected at build time.