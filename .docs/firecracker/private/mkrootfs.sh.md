<!-- docdaemon ts:2026-10-10T19:05:22Z hash:5fc3ea3264bfc38e model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds an ext4 disk image from a staging directory of files using `mkfs.ext4`.

### Purpose
`mkrootfs.sh` automates the creation of ext4 filesystem images for use in Firecracker microVMs. It handles file installation, permission setting, and final formatting into a sparse image file.

### Key Functions
- **Argument Parsing**: Accepts `--out`, `--size-mb`, `--label`, `--file`, and `--exec` flags to define output path, size, label, and file contents.
- **Staging Setup**: Creates a temporary directory (`staging`) to hold files before formatting.
- **File Installation**: Copies specified source files into the staging tree with correct permissions (0644 for regular files, 0755 for executables). Validates that destination paths are absolute.
- **Image Creation**: Uses `truncate` to create a sparse file of the requested size, then `mkfs.ext4 -d` to format it and seed it with the staging contents.

### Integration
This script is typically invoked by build rules (e.g., Bazel) to generate root filesystem images required for VM instances. It ensures consistent, reproducible image generation without requiring root privileges during the build process.