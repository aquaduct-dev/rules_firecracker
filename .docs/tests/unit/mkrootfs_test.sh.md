<!-- docdaemon ts:2026-10-10T19:05:28Z hash:7315584bffa8524e model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script unit tests the `mkrootfs` tool and validates the output of a real Firecracker rootfs target.

It verifies that `mkrootfs` correctly generates ext4 images with specified sizes, labels, and file permissions. It checks both successful creation and error handling for invalid inputs like relative paths or insufficient space. Finally, it inspects a pre-built macro output image to ensure expected binaries and files are present with correct modes.