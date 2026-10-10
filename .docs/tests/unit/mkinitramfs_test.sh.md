<!-- docdaemon ts:2026-10-10T19:05:14Z hash:59ee9564b612072e model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script validates the `mkinitramfs` tool and its associated Bazel macro by verifying archive structure, permission modes, dynamic linking rejection, and error handling.

### Purpose
The file serves as a comprehensive unit test for the Firecracker initramfs generation pipeline. It ensures that the `mkinitramfs` binary correctly packages files, executables, and BusyBox into a compressed CPIO archive while enforcing security constraints like static linking requirements.

### Key Test Scenarios
- **Happy Path**: Verifies correct directory layout (`/init`, `/bin/busybox`, etc.), file permissions (0755 for execs, 0644 for data), and symlink creation (`/bin/sh -> busybox`).
- **Dynamic Linking Rejection**: Confirms that dynamically linked ELF binaries are rejected in both `--exec` arguments and the `--busybox` source, ensuring the resulting initramfs is self-contained.
- **Usage Errors**: Checks that relative paths, unknown flags, and missing required arguments return exit code 2.
- **Macro Integration**: Unpacks the output of the `firecracker_initramfs` Bazel macro to verify that high-level build rules produce valid, expected content.

### Dependencies
- Uses `rlocation` to locate runfiles for `mkinitramfs`, `busybox`, and the macro output.
- Relies on `testlib.sh` for assertion helpers (`pass`, `fail`, `assert_rc`).