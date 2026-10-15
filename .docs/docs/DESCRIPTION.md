<!-- docdaemon ts:2026-10-15T22:44:55Z hash:1e7c4685cecf65c7 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory automates the generation and maintenance of Stardoc documentation for the Firecracker Bazel rules.

## Overview
The `docs` directory serves as the central hub for keeping API reference documentation in sync with the source code. It leverages Bazel build rules to parse Starlark definitions from `//firecracker:defs.bzl` and output structured Markdown. This automation ensures that the public interface documented in `defs.md` always reflects the current state of the codebase, preventing drift between implementation and documentation.

## Deep Dive
### Documentation Generation
The core logic resides in `BUILD.bazel`, which defines two primary targets. The `defs_docs` target invokes `stardoc` to analyze `//firecracker:defs.bzl`. This rule parses the Starlark macros—such as `firecracker_initramfs`, `firecracker_rootfs`, and various test macros—and extracts their signatures, attributes, and descriptions. The output is a generated Markdown file (`defs_generated.md`) that accurately represents the current API surface without manual intervention.

### Synchronization and Validation
To maintain consistency, the `update` target uses `write_source_files` from `aspect_bazel_lib`. It takes the output from `defs_docs` and writes it directly to `docs/defs.md`. This step effectively commits the latest documentation changes into the repository. A corresponding test, `//docs:update_test`, verifies that the generated content matches the committed version. If they diverge, the test fails, signaling that developers must run `bazel run //docs:update` to refresh the docs before committing. This CI-friendly approach prevents stale documentation from entering the main branch.

## Key Interfaces
- `defs_docs`: Target generating raw Stardoc Markdown from `//firecracker:defs.bzl`.
- `update`: Target synchronizing generated docs to `docs/defs.md`.
- `update_test`: Test ensuring committed docs match generated output.

## Dependencies
- `@aspect_bazel_lib//lib:write_source_files`
- `@io_bazel_stardoc//:stardoc`
- `//firecracker:defs.bzl` (source of truth)

## Subcomponents
- `BUILD.bazel`: Build rules for doc generation and sync.
- `defs.md`: Committed API reference documentation.