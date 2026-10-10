<!-- docdaemon ts:2026-10-10T19:05:15Z hash:901043e9ee360569 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script unit tests the `gen_test` generator by validating its ability to produce and execute microVM test scripts with various marker, timeout, and error-handling scenarios.

### Purpose
The file drives the `//firecracker:gen_test` tool against a fake microVM runner (bypassing KVM) to verify generated shell scripts handle lifecycle events correctly. It ensures the generator produces robust scripts that respect timeouts, detect markers, and fail appropriately on errors.

### Key Functions
- **`fake_runner`**: Creates a temporary executable at `$RF/fake/runner` containing the provided body, simulating a microVM process.
- **`gen`**: Invokes the generator (`$GEN`) to create a test script at `$T/t.sh`, passing arguments like `--timeout`, `--expect`, and `--unexpect`.
- **`run`**: Executes the generated script in an isolated environment (clearing `RUNFILES_MANIFEST_FILE`), capturing exit code (`$rc`), output (`$T/out`), and duration (`$secs`).

### Test Scenarios
1. **Pass**: All expected markers found, no unexpected markers.
2. **Early Exit**: Script terminates quickly when expected markers are met, even if the runner would otherwise hang.
3. **Fail - Missing Marker**: Fails if an `--expect` marker is not found.
4. **Fail - Unexpected Marker**: Fails if an `--unexpect` marker is found.
5. **Hard Deadline**: Kills hung runners after `timeout + 5s`.
6. **Environment Propagation**: Verifies `FC_TIMEOUT` is passed to the runner.
7. **Literal Matching**: Ensures special characters in markers are matched literally, not as regex/globs.
8. **No Markers**: Passes if the VM exits cleanly without any markers.
9. **Missing Runner**: Fails if the runner binary is absent.
10. **Usage Errors**: Validates generator rejects missing required flags or unknown options.