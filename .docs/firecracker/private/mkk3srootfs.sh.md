<!-- docdaemon ts:2026-10-10T19:05:20Z hash:b66e6c1c792ca526 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds a minimal, statically-linked ext4 rootfs image containing k3s and a test binary for execution within a Firecracker microVM.

### Purpose
The file automates the creation of a lightweight guest environment designed to run a single-node Kubernetes cluster (k3s) without nested container runtimes. It produces an ext4 disk image that serves as the VM's block device, ensuring all necessary binaries are self-contained and statically linked to avoid dependency issues in the isolated guest.

### Key Components
*   **ELF Validation**: Helper functions (`is_elf`, `elf_is_dynamic`) verify that input binaries (busybox, k3s, test binary) are statically linked by inspecting ELF headers using `od`. This ensures compatibility with the minimal rootfs which lacks a dynamic linker or libc.
*   **Rootfs Construction**: The script creates a staging directory structure (`/bin`, `/sbin`, `/usr/local/bin`, etc.) and populates it with:
    *   Busybox applets symlinked to a single static binary.
    *   The k3s binary along with symlinks for `kubectl`, `crictl`, and `ctr`.
    *   A generated init script (`/sbin/init`) acting as PID 1.
    *   Configuration files (`fstab`, `hosts`, `passwd`) required for basic system operation.
*   **Asset Ingestion**: Supports copying additional files, executables, Kubernetes manifests, and OCI image tarballs into specific directories within the rootfs via command-line arguments.
*   **Image Generation**: Uses `mkfs.ext4` to format the final output image, applying the specified size, label, and content from the staging directory.

### Integration
This tool is part of the Firecracker private toolchain. It bridges the host build artifacts (static binaries) with the guest execution environment, providing the launcher with a ready-to-use disk image that boots directly into a k3s cluster for integration testing.