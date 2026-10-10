<!-- docdaemon ts:2026-10-10T19:05:25Z hash:c97dd0164e71589d model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script initializes an initrd environment to verify that an extra virtual block device (`/dev/vda`) is mounted, readable, and writable.

## Purpose
The file serves as a test harness for validating storage backend functionality in a virtual machine context. It ensures that data written to the extra drive persists across mount/unmount cycles and survives a forced reboot triggered by the guest kernel.

## Key Functions
- **Mounting**: The script manually mounts `proc`, `sysfs`, and `devtmpfs` to establish a minimal userspace environment. It then attempts to mount `/dev/vda` as an `ext4` filesystem at `/mnt`.
- **Read Verification**: If the mount succeeds, it reads `/mnt/data/payload.txt` and echoes its content prefixed with `PAYLOAD=`, confirming read access to pre-baked image data.
- **Write & Persistence Test**: It writes the string `written` to `/mnt/data/new.txt`, calls `sync` to flush buffers, and unmounts the filesystem. It remounts the same device in read-only mode to verify that the previously written file exists and contains the expected value, proving persistence.
- **Reboot Trigger**: Finally, it executes `reboot -f`. This relies on the kernel command line containing `reboot=k`, which causes the Firecracker VM monitor to exit upon guest reboot, signaling successful completion of the test sequence.

## Error Handling
If the initial mount of `/dev/vda` fails, the script outputs `EXTRA_DRIVE_MOUNT_FAILED` and proceeds to reboot, indicating a critical setup error.