<!-- docdaemon ts:2026-10-19T23:24:35Z hash:4f7e3dbb94f368da model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file validates the `mkinitramfs` tool and its associated Bazel macro by verifying archive structure, permissions, ownership, and error handling.

The test suite ensures that generated initramfs images are suitable for the Firecracker microVM environment. It verifies the happy path by checking for required directory structures (`/dev`, `/proc`, etc.), correct file modes (0755 for executables, 0644 for data), and root ownership (0:0) across all entries. It explicitly confirms that busybox applets are symlinked correctly and that no self-referential symlinks exist.

Security constraints are enforced by rejecting dynamically linked binaries in `--exec` arguments, as the initramfs lacks a libc. The tool also rejects non-static busybox binaries and invalid usage patterns such as relative paths or unknown flags. Finally, it validates the output of the `firecracker_initramfs` macro to ensure high-level integration works correctly.