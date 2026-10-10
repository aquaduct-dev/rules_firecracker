<!-- docdaemon ts:2026-10-10T19:04:47Z hash:00291ce6f5f13b17 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines the Bazel module manifest for the end-to-end smoke test workspace, configuring it to consume `rules_firecracker` as an external dependency.

### Purpose
The `MODULE.bazel` file establishes the `rules_firecracker_e2e_smoke` module, which serves as an isolated environment to validate `rules_firecracker` from the perspective of an external consumer. This setup ensures that label resolution and runfiles handling work correctly outside the rules' own repository context. It also functions as the official BCR (Bazel Central Registry) test module.

### Configuration Details
*   **Module Definition**: Declares the module name as `rules_firecracker_e2e_smoke`.
*   **Primary Dependency**: Imports `rules_firecracker` version `0.0.0`. The `local_path_override` directive redirects this dependency to the parent directory (`../..`), allowing the smoke test to use the local development version of the rules rather than a published release.
*   **Secondary Dependency**: Includes `rules_shell` version `0.6.1`, providing necessary shell utilities for the test suite.