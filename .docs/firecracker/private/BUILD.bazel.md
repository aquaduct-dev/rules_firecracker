<!-- docdaemon ts:2026-10-10T19:04:51Z hash:d207c86acc393d1c model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines the public visibility for helper scripts and templates while exposing the internal macro library to the local package.

### Purpose
The `BUILD.bazel` file serves as the build configuration for the private implementation details of `rules_firecracker`. It ensures that necessary runtime assets are accessible and that the core macro logic is available for instantiation by caller packages.

### Key Components

#### Exports Files
The `exports_files` rule makes shell scripts (`.sh`), templates (`.tpl`), and configuration files (`.config`) publicly visible. These files are read by `genrule`s instantiated in the caller's package via macros defined in `//firecracker:defs.bzl`.

#### Bazel Library
The `bzl_library` target named `macros` compiles `macros.bzl` into a loadable library.
- **Visibility**: Restricted to `//firecracker:__pkg__`, ensuring it is only usable within this specific package.
- **Dependencies**: Depends on `@rules_shell//shell:rules_bzl` to provide shell-related rules used by the macros.