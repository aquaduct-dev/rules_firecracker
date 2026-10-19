<!-- docdaemon ts:2026-10-19T23:24:31Z hash:feac8b386be195f2 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script verifies that the Firecracker binary is present and reports a valid version string.

It locates the pinned `firecracker` binary via Bazel runfiles using the `FC_RLOC` variable, ensuring the test does not rely on the host PATH. The script executes `--version` once to minimize overhead and avoid race conditions associated with multiple invocations. It parses the first line of output, stripping any trailing newlines, and asserts that it matches the expected `Firecracker v*` prefix. This strict validation prevents false positives from unexpected outputs or parsing errors in downstream harnesses. If the format is incorrect, the script exits with an error immediately.