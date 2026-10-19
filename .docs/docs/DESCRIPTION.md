<!-- docdaemon ts:2026-10-19T23:25:23Z hash:109bf528eb01b844 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains the generated API reference documentation for the Firecracker Bazel rules and the build orchestration logic to keep it synchronized with source code.

## Overview
The `docs` directory serves as the single source of truth for public API documentation regarding Linux boot image generation and microVM testing within the Bazel workspace. It ensures that developers have accurate, up-to-date references for macros like `firecracker_test`, `firecracker_cluster_test`, and `firecracker_k3s_test`. By automating the regeneration process, the directory prevents documentation drift between the Bazel macro definitions in `//firecracker:defs.bzl` and the human-readable reference.

## Deep Dive
### Documentation Generation
The core mechanism relies on Stardoc to parse the Starlark definitions in `//firecracker:defs.bzl`. The `defs_docs` target extracts docstrings and attribute descriptions from macros such as `firecracker_initramfs` and `firecracker_rootfs`, outputting a structured Markdown file (`defs_generated.md`). This automated approach captures changes to argument types, default values, and behavioral descriptions immediately upon code modification.

### Synchronization and Validation
To maintain consistency, the `update` target copies the generated content into `docs/defs.md`. A dedicated CI test (`//docs:update_test`) compares the committed file against the freshly generated output. If discrepancies exist, the test fails, enforcing that any change to the Bazel rules must be accompanied by a regenerated documentation commit. This pipeline eliminates manual synchronization errors and ensures the README reflects the current state of the `firecracker_microvm` and related integration tests.

## Key Interfaces
- `defs_docs`: Stardoc rule generating `defs_generated.md` from `//firecracker:defs.bzl`.
- `update`: Rule copying generated docs to `docs/defs.md`.
- `update_test`: CI check validating documentation sync status.

## Dependencies
- `stardoc`: For parsing Starlark docstrings.
- `rules_python` (write_source_files): For file copying operations.
- `//firecracker:defs.bzl`: Source of truth for API definitions.

## Subcomponents
- `BUILD.bazel`: Build targets for generation and sync.
- `defs.md`: Committed API reference documentation.