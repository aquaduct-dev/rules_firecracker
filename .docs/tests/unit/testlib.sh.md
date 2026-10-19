<!-- docdaemon ts:2026-10-19T23:24:29Z hash:2d534ef69dd606c9 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file provides shared shell utilities for unit testing, including assertion helpers, ELF binary inspection, and ext4 image analysis.

### Purpose
Sourced after `runfiles.bash`, it establishes a test environment by ensuring `sbin` tools (like `debugfs`) are on the `PATH`. It manages a temporary directory (`T`) and tracks failure counts to report results via `finish`.

### Key Functions

**Assertions**
*   `assert_contains` / `assert_not_contains`: Verify substring presence in files using `grep -qF`. On failure, they dump the file content to stderr.
*   `assert_rc`: Validates return codes, supporting exact integer matches or a special `nonzero` check.

**ELF Inspection**
*   `mkelf`: Generates minimal little-endian ELF64 binaries with specified program header types (e.g., `PT_INTERP` for dynamic linking).
*   `is_elf`: Checks for the standard ELF magic bytes using `od`.
*   `elf_is_dynamic`: Parses ELF headers to detect `PT_INTERP` (type 3), determining if a binary requires a dynamic loader. Handles both 32-bit and 64-bit classes.

**Ext4 Image Analysis**
*   `debugfs_cat`: Extracts file contents from an ext4 image without mounting.
*   `debugfs_mode`: Retrieves octal permission bits.
*   `debugfs_owner`: Extracts UID:GID ownership.
*   `debugfs_exists`: Checks inode existence.

These tools support tests that validate guest image construction, specifically ensuring correct permissions and binary linkage properties as required by recent build system changes.