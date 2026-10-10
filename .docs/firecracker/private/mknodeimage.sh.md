<!-- docdaemon ts:2026-10-10T19:05:20Z hash:b035d0f7cd8ff2cb model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds a self-contained Debian-based ext4 image for openfactoryd nodes, bundling the kernel, firmware, NetworkManager, k3s, and the openfactoryd daemon.

## Purpose
It generates a bootable root filesystem image that runs its own kernel (unlike previous minimal rootfs approaches). The resulting image is designed to be booted via GRUB with `root=LABEL=OFD_ROOTFS`, providing a complete environment for edge node operations.

## Key Functions
- **Argument Parsing**: Validates required inputs for output path, binaries (`k3s`, `openfactoryd`), systemd units, and image size/label.
- **Base Image Construction**: Creates a temporary Dockerfile based on `debian:12-slim`. It installs essential packages including `systemd`, `linux-image-amd64`, `initramfs-tools`, and various hardware firmwares. It configures stable symlinks in `/boot` and sets the filesystem label in `/etc/fstab`.
- **Filesystem Assembly**: Exports the Docker container's filesystem into a tarball. Under `fakeroot`, it extracts this base, installs the provided binaries and service files, creates necessary directories, and links k3s tools. Finally, it formats an ext4 image with the specified size and label, populating it with the assembled root directory.

## Integration
This tool is part of the build pipeline for openfactoryd nodes. It replaces older methods that relied on host kernels, ensuring each node has a consistent, isolated, and fully functional OS environment ready for provisioning by `ofd-provision`.