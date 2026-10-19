<!-- docdaemon ts:2026-10-19T23:24:35Z hash:fc0add34ee486365 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script validates the `mkrootfs` tool and the generated Firecracker rootfs macro by inspecting ext4 images with `debugfs`.

It verifies that `mkrootfs` correctly creates ext4 images of specified sizes, applies volume labels, and embeds files with correct content, permissions (0644 for regular files, 0755 for executables), and ownership (root:root). It also ensures error handling works for invalid inputs like relative paths, missing size arguments, or insufficient image capacity. Finally, it checks a pre-built macro output to confirm standard guest components like `/sbin/init`, `/bin/busybox`, and greeting files are present and correctly configured.