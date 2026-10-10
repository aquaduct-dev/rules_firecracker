<!-- docdaemon ts:2026-10-10T19:04:46Z hash:37eaf3c7e98f6214 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines the `rules_firecracker` module, its dependencies, and pinned external binaries required for building and testing Firecracker microVMs.

### Module Configuration
The module declares `rules_firecracker` at version `0.0.0`. It depends on `bazel_skylib`, `platforms`, and `rules_shell` for core functionality. Development dependencies include `rules_go`, `stardoc`, `aspect_bazel_lib`, and `rules_oci` to support self-tests, documentation generation, and OCI image creation. A Go SDK (v1.25.4) is configured via extension for Go-based test runners.

### Pinned Binaries
To ensure hermetic builds, critical binaries are fetched via `http_archive` and `http_file`:

*   **Firecracker VMM**: Pre-built x86_64 and aarch64 binaries (v1.17.0) are downloaded from GitHub releases. These provide the `firecracker` binary without requiring host installation.
*   **jq**: A static Linux binary (v1.8.1) is included for JSON validation in guest-side tests.
*   **Kernel Source**: Linux 6.1.155 source tarball is pinned to allow local building of a custom kernel with FUSE support and entropy configuration.
*   **Busybox**: A static musl-linked Busybox binary (v1.35.0) serves as the initramfs base.
*   **k3s**: A static k3s binary (v1.30.4) is provided for integration tests that run Kubernetes inside the microVM.

### Upgrade Process
When updating pinned versions, update the `urls`, `strip_prefix` (if applicable), and `sha256` fields. Verify checksums against official release assets to maintain integrity.