<!-- docdaemon ts:2026-10-10T19:04:47Z hash:440bf99561726154 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines the Bazel build configuration for the `rules_firecracker` project, primarily managing license distribution.

### Purpose
The `BUILD.bazel` file serves as the root build target for the repository. Its primary function is to expose the project's licensing information to consumers of the rules via the Bazel export mechanism.

### Key Elements
*   **`exports_files(["LICENSE"])`**: This rule makes the `LICENSE` file available in the package. It allows other targets or users to reference the license text directly without needing to know its internal path structure. This is standard practice for open-source Bazel repositories to ensure compliance metadata is easily accessible.

### Context
This file sits at the root of the `rules_firecracker` workspace. It works in conjunction with:
*   `README.md`: Provides usage instructions and context for the rules.
*   `//firecracker:defs.bzl`: Contains the public API definitions (macros and rules) that this build system supports.

By exporting the license, this file ensures that any binary or source artifact built within this workspace can correctly attribute the project's legal terms.