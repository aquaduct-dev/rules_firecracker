<!-- docdaemon ts:2026-10-19T23:24:31Z hash:8a0ca18a446d0c71 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file orchestrates the generation and synchronization of Stardoc documentation for the `//firecracker:defs.bzl` module.

It defines two primary targets to automate API reference maintenance:

1.  **`defs_docs`**: A `stardoc` rule that parses `//firecracker:defs.bzl` (including its dependencies) and outputs a Markdown file named `defs_generated.md`. This serves as the source of truth for the generated API documentation.
2.  **`update`**: A `write_source_files` rule that copies `defs_generated.md` into the repository as `docs/defs.md`. This ensures the committed documentation always reflects the current state of the Bazel macros.

The setup supports an automated CI check (`//docs:update_test`) which compares the committed `docs/defs.md` against the generated output. If they differ, it indicates that `//firecracker:defs.bzl` was modified without regenerating docs, causing the test to fail. This enforces consistency between code changes and their public API documentation.