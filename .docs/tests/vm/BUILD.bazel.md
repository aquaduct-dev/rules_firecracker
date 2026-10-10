<!-- docdaemon ts:2026-10-10T19:05:23Z hash:58de4767f9f7d8c9 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This Bazel build file defines single-VM integration tests that boot real microVMs using Firecracker and validate their behavior via serial console output.

It loads custom Starlark rules (`firecracker_initramfs`, `firecracker_microvm`, `firecracker_rootfs`, `firecracker_test`) to construct VM configurations and assertions. The file organizes tests into logical groups: initrd boot, rootfs boot, extra drive handling, timing/timeout behavior, and failure path verification.

Key components include:
*   **Image Definitions**: `firecracker_initramfs` and `firecracker_rootfs` create bootable images with specified executables, files, and labels.
*   **VM Configurations**: `firecracker_microvm` instances specify resources (vCPUs, memory) and boot sources (initrd, rootfs, extra drives).
*   **Test Assertions**: `firecracker_test` rules define expected and unexpected serial console markers to pass or fail the test.
*   **Wrapper Tests**: Shell tests (`sh_test`) wrap inner manual tests to verify that specific failure conditions (missing markers, unexpected markers, timeouts) are correctly detected and reported.