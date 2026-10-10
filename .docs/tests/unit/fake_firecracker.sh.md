<!-- docdaemon ts:2026-10-10T19:05:04Z hash:a1453066b1f3dc0a model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script serves as a mock implementation of the Firecracker virtual machine monitor, capturing invocation arguments and file system interactions for unit testing.

## Purpose
The `fake_firecracker.sh` script replaces the actual Firecracker binary during test execution. It allows the microvm macros to invoke the VMM without starting real virtual machines, enabling assertions on how the launcher interacts with the tool.

## Key Behaviors

### Version Handling
If invoked with `--version`, it outputs `Firecracker vFAKE` and exits immediately, satisfying version checks in the test harness.

### Argument Recording
All command-line arguments are logged to standard output prefixed with `FAKE_FIRECRACKER_ARGS=`. This allows tests to verify the exact configuration passed by the launcher.

### Configuration File Extraction
The script parses arguments to locate the `--config-file` flag. If found, the value is stored in the `cfg` variable for subsequent operations.

### State Dumping
When the environment variable `FAKE_FC_DUMP` is set:
1. The extracted config file (`$cfg`) is copied to `$FAKE_FC_DUMP/vm.json`.
2. The current working directory is written to `$FAKE_FC_DUMP/cwd`.

### Resource Resolution Simulation
The script checks for the existence of specific disk images: `vmlinux.bin`, `initrd.cpio.gz`, `rootfs.ext4`, and `extra.img`. If any exist, it prints `RESOLVES:<filename>` to stdout.

### Rootfs Write Check
It verifies if `rootfs.ext4` is writable. If so, it prints `ROOTFS_WRITABLE_COPY` to indicate the test environment supports write operations on the root filesystem.

### Controlled Delay and Exit
- If `FAKE_FC_SLEEP` is set, the script pauses for the specified duration.
- The exit code defaults to `0` but can be overridden via the `FAKE_FC_EXIT` environment variable.