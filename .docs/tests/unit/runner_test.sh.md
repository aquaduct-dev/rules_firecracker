<!-- docdaemon ts:2026-10-19T23:24:37Z hash:adca671e28ee576c model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file validates the `firecracker_microvm` launcher's configuration generation, runtime overrides, and error handling in a non-KVM environment.

It uses a fake Firecracker binary to capture the generated `vm.json` and verify correctness against expected values for CPU, memory, boot sources, and network interfaces. The test suite covers:

*   **Boot Modes:** Both initrd and rootfs configurations, including extra drives and persistent disks.
*   **Runtime Knobs:** Environment variables like `FC_TAP`, `FC_GUEST_MAC`, `FC_CMDLINE_EXTRA`, `FC_PERSIST_DISK`, `FC_BOOT_DISK`, and `FC_ROOT_PART`.
*   **Overrides:** Custom `FC_FIRECRACKER` binaries and timeout enforcement via `FC_TIMEOUT`.
*   **Path Resolution:** Ensures no host PATH lookup occurs for the Firecracker binary, relying instead on runfiles resolution, even with relative paths.
*   **Error Handling:** Verifies that missing files or non-zero exit codes from the underlying process are correctly propagated or handled.