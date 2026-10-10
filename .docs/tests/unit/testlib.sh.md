<!-- docdaemon ts:2026-10-10T19:05:24Z hash:905f1876c80b9404 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file provides shared shell utilities for unit testing, including assertion helpers, ELF binary inspection tools, and ext4 image interaction functions.

### Purpose
It serves as a test harness library sourced after `runfiles.bash`. It manages the test environment (PATH, temp directory), tracks pass/fail counts, and provides specific helpers for validating ELF binaries and ext4 filesystem images without mounting them.

### Key Functions

**Test Framework**
*   `fail` / `pass`: Increment the failure counter or log success.
*   `finish`: Exits with status 1 if any checks failed, otherwise exits successfully.
*   `assert_contains` / `assert_not_contains`: Verify substring presence in files using `grep`.
*   `assert_rc`: Assert that a command's return code matches an expected value (exact integer or "nonzero").

**ELF Binary Helpers**
*   `mkelf`: Generates a minimal little-endian ELF64 executable header with specified program header types. Useful for creating test fixtures.
*   `is_elf`: Checks if a file starts with the ELF magic bytes (`\x7fELF`).
*   `elf_is_dynamic`: Determines if an ELF binary is dynamically linked by inspecting program headers for `PT_INTERP` (type 3). Uses `od` for parsing.

**Ext4 Image Helpers**
*   `debugfs_cat`: Extracts file content from an ext4 image using `debugfs -R cat`.
*   `debugfs_mode`: Extracts octal permission bits from an ext4 image using `debugfs -R stat`.
*   `debugfs_exists`: Checks for the existence of a path within an ext4 image via `debugfs -R stat`.