<!-- docdaemon ts:2026-10-10T19:05:19Z hash:284fc2c67cc52eb6 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script generates a compressed cpio+gzip initramfs image for Firecracker by packaging a statically-linked BusyBox, an init binary, and additional files into a minimal root filesystem.

## Purpose
The script automates the creation of a lightweight initial RAM filesystem required to boot a Firecracker microVM. It ensures all binaries within the archive are statically linked, as the initramfs environment lacks a dynamic linker or C library.

## Key Components

### ELF Validation
To guarantee compatibility, the script includes inline helpers (`is_elf`, `elf_is_dynamic`) that parse ELF headers using `od`. These functions verify that provided binaries are static executables, rejecting any dynamically linked artifacts that would fail at runtime.

### Filesystem Assembly
A temporary directory structure is created to mimic the target root layout (`/bin`, `/sbin`, `/etc`, etc.). The script:
1. Installs the specified BusyBox binary and creates symlinks for all its applets in `/bin` and key utilities in `/sbin`.
2. Installs the primary init process (`/init`).
3. Copies user-specified files (`--file`) with mode `0644` and executables (`--exec`) with mode `0755`.
4. Generates a standard `fstab` for proc, sysfs, devtmpfs, tmpfs, and run mounts.

### Archiving
The final image is produced by sorting the file tree and piping it through BusyBox’s built-in `cpio` and `gzip` utilities. This approach avoids dependencies on host-specific tools like `cpio` or `gzip`, ensuring consistent behavior across different build environments. Timestamps are zeroed to improve reproducibility, though inode numbers may still vary.