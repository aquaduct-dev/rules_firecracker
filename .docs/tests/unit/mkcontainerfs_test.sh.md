<!-- docdaemon ts:2026-10-10T19:05:15Z hash:59130300088b8d9b model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file is a Bash unit test that verifies `mkcontainerfs` correctly flattens an OCI image layout into an ext4 filesystem, handling whiteouts, environment variables, and entrypoint generation.

It constructs a two-layer OCI layout manually using `tar`, `sha256sum`, and JSON manifests to simulate complex scenarios like file deletion (whiteouts) and directory opacity. The test then invokes the `mkcontainerfs` tool against this layout and validates the resulting ext4 image using `debugfs`.

Key verification points include:
- **Layer Merging**: Ensures lower-layer files are removed when upper layers contain corresponding `.wh.` markers or opaque directory markers (`..wh..opq`).
- **Init Script Generation**: Checks that `/sbin/init` is created with correct permissions (0755) and contains the expected shell commands, including merged environment variables where command-line overrides take precedence over image-defined ones.
- **Error Handling**: Confirms that missing entrypoints/commands result in rejection, and malformed extra arguments are caught.