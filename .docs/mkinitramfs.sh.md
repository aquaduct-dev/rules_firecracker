<!-- docdaemon ts:2026-10-09T22:28:56Z hash:b8181f0fc72846ba model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script generates a compressed cpio+gzip initramfs image by assembling a minimal root filesystem with BusyBox and specified binaries.

## Purpose
`mkinitramfs.sh` automates the creation of an initial RAM filesystem (initramfs) for Linux booting. It constructs a temporary directory structure, populates it with essential utilities, and archives it into a single output file suitable for kernel loading.

## Key Functions
- **Argument Parsing**: Handles required flags (`--out`, `--busybox`, `--init`) and repeatable lists (`--file`, `--exec`).
- **BusyBox Integration**: Installs the statically-linked BusyBox binary and creates symlinks for all applets in `/bin` and critical system commands in `/sbin`.
- **File Installation**: Copies user-specified files to absolute paths within the rootfs with appropriate permissions (0644 for data, 0755 for executables).
- **Static Linkage Verification**: Checks ELF binaries provided via `--exec` to ensure they are statically linked, preventing runtime failures due to missing libc.
- **Archiving**: Uses `find` and `cpio` to create a newc-format archive, which is then compressed with gzip level 9.

## Usage Context
This tool is typically invoked during build processes to generate the initial ramdisk image passed to the kernel via bootloader configuration or QEMU arguments.