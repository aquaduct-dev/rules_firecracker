<!-- docdaemon ts:2026-10-19T23:24:35Z hash:0d4c5a1815f1517f model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script validates the `mkk3srootfs` tool by verifying that it correctly constructs an ext4 root filesystem with expected files, permissions, symlinks, and ownership.

The test ensures the builder accepts valid inputs (busybox, k3s init, static binaries) and rejects invalid ones (dynamically linked binaries, missing required arguments). It checks for specific inclusions such as `/sbin/init`, `/usr/local/bin/k3s`, and custom manifests/images injected via command-line flags.

Key verifications include:
- **File Presence**: Confirms all specified binaries, configs, and extra files exist in the output image.
- **Symlinks**: Verifies that `kubectl` is symlinked to `k3s`.
- **Permissions & Ownership**: Ensures binaries are executable (`0755`), text files are readable (`0644`), and all inodes are owned by root (`0:0`). This re-ownership step addresses issues where build artifacts retained the host user's UID/GID.
- **Error Handling**: Asserts that dynamically linked test or k3s binaries are rejected, and that missing mandatory flags like `--test-binary` cause failure.