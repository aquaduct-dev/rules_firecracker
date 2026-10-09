<!-- docdaemon ts:2026-10-09T22:28:57Z hash:d850adfa8c195a7e model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds a minimal ext4 rootfs image containing a statically linked k3s cluster, busybox utilities, and a guest-side test binary for execution inside a Firecracker VM.

## Purpose
The file automates the creation of a self-contained Linux environment optimized for running a single-node Kubernetes cluster (k3s) within an isolated virtual machine. It ensures all binaries are statically linked to avoid dependency issues in the minimal rootfs.

## Key Functions
- **Argument Parsing**: Handles flags for output path (`--out`), source binaries (`--busybox`, `--k3s`, `--init`, `--test-binary`), and configuration files (`--manifest`, `--image`).
- **Validation**: Checks that required arguments are present and verifies that provided binaries are statically linked using the `file` command.
- **Staging Area Setup**: Creates a temporary directory structure mirroring the final rootfs layout, including `/bin`, `/sbin`, `/usr/local/bin`, and various system directories.
- **Binary Installation**: Installs Busybox with symlinks for applets, copies the k3s binary along with aliases (`kubectl`, `crictl`, `ctr`), and places the init script and test binary.
- **Configuration Generation**: Writes essential system files like `fstab`, `resolv.conf`, `hostname`, `hosts`, `passwd`, and `group` to ensure basic OS functionality and network resolution.
- **File Copying**: Processes repeatable arguments to copy additional files, executables, manifests, and OCI images into their respective directories within the staging area.
- **Image Creation**: Uses `mkfs.ext4` to create the final ext4 image from the staging directory, applying the specified size and label.

## Integration
This script is part of a larger toolchain for testing k3s in constrained environments. It produces the disk image consumed by the host launcher, which boots the VM via Firecracker. The resulting image allows the host to scrape test reports printed to `/dev/console`.