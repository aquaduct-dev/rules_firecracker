<!-- docdaemon ts:2026-10-10T19:04:44Z hash:1b975d4f9bc1d97c model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file orchestrates the generation and synchronization of Stardoc documentation for the `//firecracker:defs.bzl` module.

It defines two primary targets to automate API reference maintenance. The `defs_docs` target uses `stardoc` to parse the Starlark definitions in `//firecracker:defs.bzl` and produce a Markdown file (`defs_generated.md`). This ensures that the public interface is accurately reflected in the documentation based on current code.

The `update` target utilizes `write_source_files` from `aspect_bazel_lib`. It takes the generated output from `defs_docs` and writes it to `docs/defs.md`. This step effectively commits the latest documentation changes into the repository.

Together, these rules support the CI workflow described in the comments: running `bazel run //docs:update` regenerates the docs, while the associated test (`//docs:update_test`) fails if the generated content diverges from the committed version, preventing stale documentation.