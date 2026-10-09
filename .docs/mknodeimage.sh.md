<!-- docdaemon ts:2026-10-09T22:28:58Z hash:b035d0f7cd8ff2cb model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds a self-contained, bootable Debian ext4 image for openfactoryd nodes, bundling the kernel, firmware, k3s, and daemon binaries into a single distributable artifact.

## Purpose
`mknodeimage.sh` automates the creation of a root filesystem image that boots independently via GRUB. Unlike previous minimal rootfs approaches, this image includes its own kernel, initramfs, and NetworkManager, eliminating the need for host-kernel injection or per-capability patching. It is designed to be deployed directly to node hardware.

## Key Functions

### 1. Base Image Construction
The script generates a temporary Dockerfile based on `debian:12-slim`. It configures APT sources to include `non-free-firmware`, installs essential packages (`systemd`, `linux-image-amd64`, `firmware-*`, `network-manager`), and sets up stable symlinks in `/boot` for GRUB compatibility. The resulting container serves as the base filesystem layer.

### 2. Filesystem Extraction
It creates a container from the base image, exports the filesystem contents to a tarball, and removes the container. This provides a clean, unmodified Debian rootfs ready for customization.

### 3. Payload Injection and Packaging
Using `fakeroot`, the script extracts the base tarball into a working directory. It then:
- Installs provided binaries (`k3s`, `openfactoryd`, `ofd-provision`, `ofd-nodewatch`) with appropriate permissions.
- Deploys systemd service units and enables them by creating symlinks in `multi-user.target.wants`.
- Creates necessary directories for state and configuration (`/var/lib/openfactoryd`, `/etc/rancher`).
- Generates an ext4 image of the specified size and label, populating it with the prepared rootfs.

## Integration
This tool is part of the build pipeline for openfactoryd nodes. It consumes pre-built binaries and service definitions as arguments, producing a final `.img` file that can be flashed to storage devices. The output image is intended to be booted by GRUB, which passes `root=LABEL=${LABEL}` to the kernel.