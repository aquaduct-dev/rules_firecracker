<!-- docdaemon ts:2026-10-10T19:05:20Z hash:26509ea434102805 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script converts an OCI image layout into a bootable ext4 root filesystem for Firecracker.

It flattens image layers while respecting AUFS whiteouts, installs a statically-linked BusyBox, and generates a custom `/sbin/init` script that mounts virtual filesystems and executes the container entrypoint. The tool ensures the resulting image is self-contained, requiring no external shell or dynamic libraries at runtime.

### Key Components

*   **ELF Validation**: Helper functions (`is_elf`, `elf_is_dynamic`) verify that the provided BusyBox binary is statically linked, ensuring portability across different host environments.
*   **Layer Processing**: It iterates through layer digests extracted from `index.json`. Each layer is extracted to a temporary directory where `.wh.*` markers are processed to delete files or clear directories before merging onto the rootfs.
*   **Init Generation**: A Python snippet reads the image configuration (Env, Entrypoint, Cmd, WorkingDir) and appends any `--extra-env` or `--extra-arg` flags. It writes a shell script to `/sbin/init` that mounts `/proc`, `/sys`, and `/dev`, then executes the container command.
*   **Image Creation**: Finally, it creates a sparse file of the specified size and formats it as ext4 using the staged rootfs as a seed directory.

### Usage
The script requires four mandatory arguments: `--out` (output path), `--image-dir` (OCI layout), `--busybox` (static binary path), and `--size-mb` (disk size). Optional flags allow injecting environment variables and command-line arguments.