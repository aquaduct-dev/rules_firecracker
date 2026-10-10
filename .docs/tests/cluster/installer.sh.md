<!-- docdaemon ts:2026-10-10T19:04:57Z hash:1cc7ca0f3ae8ffb8 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script provisions a block device with a GPT partition layout and injects cluster configuration into the root filesystem image.

## Purpose
Acting as a generic installer for `firecracker_install_cluster_test`, this script prepares a target disk for boot. It formats the disk, creates an EFI System Partition (ESP) and an OFD Root Filesystem partition, and writes a modified rootfs image to the second partition.

## Key Functions
- **Argument Parsing**: Accepts `--settings` (path to `settings.ini`) and `--rootfs-image` (path to `.ext4`).
- **Configuration Loading**: Extracts `target_disk`, `cluster_secret`, and `wipe_confirm` from the INI file using `ini`.
- **Disk Preparation**: Zaps existing partitions and uses `sgdisk` to create:
  - Partition 1: 8 MiB ESP (`ef00`).
  - Partition 2: Full remaining space OFD RootFS (`8300`).
- **Image Modification**: Copies the rootfs to a temp directory, writes `cluster_secret` into `/etc/installed-settings` within the ext4 filesystem using `debugfs`, and syncs changes.
- **Writing**: Uses `dd` to write the modified rootfs to partition 2, respecting sector alignment.

## Security Note
The script reads `cluster_secret` from the settings file and injects it directly into the filesystem. Ensure the settings file permissions restrict access to authorized users only.