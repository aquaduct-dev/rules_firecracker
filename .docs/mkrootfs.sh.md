<!-- docdaemon ts:2026-10-09T22:28:56Z hash:5fc3ea3264bfc38e model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds an ext4 disk image from a staging directory of files using `mkfs.ext4`.

It accepts command-line arguments to specify the output path, image size, and filesystem label. It supports two types of file inclusions: standard files (mode 0644) and executables (mode 0755), specified via `--file` and `--exec` flags respectively. The script creates a temporary staging area, populates it with the specified files, and then uses `truncate` to create a sparse file of the requested size. Finally, it formats this file as ext4, seeding it with the staging contents.

Key behaviors include:
- **Dependency Management**: Ensures `/usr/sbin` is in the PATH for `mkfs.ext4` availability.
- **Validation**: Checks for required arguments (`--out`, `--size-mb`, `--label`) and verifies that destination paths are absolute.
- **Cleanup**: Uses a trap to remove the temporary working directory on exit.
- **Formatting**: Calls `mkfs.ext4 -F -q -L <label> -d <staging>` to generate the final image.