<!-- docdaemon ts:2026-10-10T19:05:46Z hash:85276b4ffce1dd65 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains integration tests for Firecracker microVMs, validating boot sequences, storage backends, and failure modes via serial console assertions.

## Overview
The `tests/vm` suite verifies the correctness of VM image construction and runtime behavior using Bazel’s custom Starlark rules. It covers positive scenarios like successful initrd and rootfs boots, as well as negative cases such as timeout detection and missing markers. By leveraging real microVMs, these tests ensure that the underlying infrastructure correctly handles memory, vCPUs, and block device persistence.

## Deep Dive
### Image Construction
Custom rules (`firecracker_initramfs`, `firecracker_rootfs`) assemble bootable images from static assets like `greeting.txt` and `payload.txt`. These rules embed executables and configuration files into minimal Linux environments, ensuring deterministic build outputs for reproducible testing.

### Boot Validation
Scripts like `initrd_init.sh` and `rootfs_init.sh` act as PID 1 processes within the guest. They verify critical system state, including CPU count, memory bounds, and file accessibility (e.g., reading `/etc/greeting`). Successful validation triggers a controlled reboot, signaling test completion to the host.

### Storage Testing
`extra_drive_init.sh` validates virtual block device functionality by mounting an ext4 filesystem on `/dev/vda`. It performs read/write cycles and persistence checks across mount/unmount operations, ensuring data integrity under simulated load.

### Failure & Timeout Handling
Wrapper scripts like `expect_failure.sh` and `hang_init.sh` test robustness. The hang script forces timeouts by entering infinite loops, while the wrapper asserts that specific diagnostic messages appear when expected failures occur, verifying error reporting mechanisms.

## Key Interfaces
*   `firecracker_microvm`: Defines VM resource constraints and boot sources.
*   `firecracker_test`: Asserts serial console output against expected patterns.
*   `expect_failure.sh`: Wrapper for verifying negative test outcomes and timeouts.
*   `initrd_init.sh` / `rootfs_init.sh`: Guest-side entry points for boot validation.

## Dependencies
*   Bazel Build System
*   Firecracker MicroVM Emulator
*   Linux Kernel (with `reboot=k` support)
*   BusyBox (for minimal userspace utilities)

## Subcomponents
*   `BUILD.bazel`: Test definitions and rule configurations.
*   `expect_failure.sh`: Negative test wrapper.
*   `extra_drive_init.sh`: Block device validation script.
*   `greeting.txt`: Static text fixture.
*   `hang_init.sh`: Timeout trigger script.
*   `initrd_init.sh`: Initrd boot validation script.
*   `payload.txt`: Binary/text payload source.
*   `rootfs_greeting.txt`: Rootfs-specific greeting fixture.
*   `rootfs_init.sh`: Rootfs boot validation script.