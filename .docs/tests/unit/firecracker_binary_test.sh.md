<!-- docdaemon ts:2026-10-10T19:05:02Z hash:07fa4b4334466a7e model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script validates that the Firecracker binary is statically linked, executable, and reports the expected version string.

### Purpose
The file serves as a unit test to verify the integrity of the `firecracker` binary artifact produced by the build system. It ensures the binary meets specific runtime requirements before it is used in integration tests.

### Key Checks
- **Executable Status**: Confirms the binary located at `$FC` has execute permissions.
- **Static Linking**: Verifies the binary is a static ELF executable using helper functions `is_elf` and `elf_is_dynamic`. This ensures portability across host environments.
- **Version Consistency**: Executes `--version` in an isolated environment (`env -i`) and asserts the output matches `Firecracker v1.17.0`.

### Dependencies
- Sourced from `testlib.sh`, which provides assertion helpers like `pass`, `fail`, `is_elf`, and `finish`.
- Relies on Bazel runfiles resolution via `rlocation` to locate the binary and test utilities.