<!-- docdaemon ts:2026-10-10T19:07:02Z hash:8897bd48f8538f7b model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory manages the automated generation and synchronization of Stardoc documentation for Firecracker Bazel rules.

## Overview
The `docs` directory ensures that the public API defined in `//firecracker:defs.bzl` remains accurate and up-to-date by automating the creation of reference materials. It leverages `stardoc` to parse Starlark definitions and `aspect_bazel_lib` to commit the resulting Markdown files, preventing documentation drift through CI-enforced tests. This setup provides a reliable source of truth for developers using the Firecracker microVM build system.

## Deep Dive
### Documentation Generation
The `defs_docs` target utilizes `stardoc` to analyze `//firecracker:defs.bzl`. It extracts rule and macro definitions, producing a structured Markdown file (`defs_generated.md`) that reflects the current public interface. This process ensures that API references are derived directly from the codebase rather than maintained manually.

### Synchronization and Validation
The `update` target employs `write_source_files` from `aspect_bazel_lib` to move generated content into `docs/defs.md`. This step commits the latest documentation to the repository. A corresponding test (`//docs:update_test`) verifies that the committed file matches the generated output. If they diverge, the test fails, enforcing strict consistency between code and documentation during continuous integration.

## Key Interfaces
- `//docs:defs_docs`: Target for generating Stardoc Markdown from `//firecracker:defs.bzl`.
- `//docs:update`: Target for synchronizing generated docs to `docs/defs.md`.
- `//docs:update_test`: Test target ensuring documentation sync integrity.

## Dependencies
- `stardoc`: For parsing Starlark definitions.
- `aspect_bazel_lib`: Specifically `write_source_files` for file management.
- `//firecracker:defs.bzl`: The source module being documented.

## Subcomponents
- `BUILD.bazel`: Build rules for doc generation and sync.
- `defs.md`: The committed, synchronized documentation file.