<!-- docdaemon ts:2026-10-19T23:24:32Z hash:d678479a93cbadb7 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds an ext4 disk image from a staging directory, ensuring all files are root-owned for guest VM compatibility.

It accepts arguments to specify the output path, size, label, and file sets (regular vs executable). It creates a temporary staging tree, populates it with the specified files using `install`, and formats the image using `mkfs.ext4 -d`.

Because `mkfs.ext4` preserves the ownership of the build user, the script uses `debugfs` to recursively re-own every inode in the resulting image to UID/GID 0. This ensures the guest environment sees standard root permissions without requiring host root access or fakeroot. The script validates that required tools (`mkfs.ext4`, `debugfs`) are available and cleans up temporary files on exit.