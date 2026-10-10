<!-- docdaemon ts:2026-10-10T19:05:20Z hash:032dca42fc5d6881 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file contains unit tests for the `mkk3srootfs` script, verifying that it correctly constructs a K3s root filesystem image with specified binaries, manifests, and configuration files.

The test suite validates the core functionality of the rootfs builder by checking for the presence and correct permissions of key components such as the busybox binary, k3s executable, init script, and various injected files (manifests, images, and extra text files). It also verifies symbolic links, such as `kubectl` pointing to `k3s`, and ensures that scenario-specific metadata is written correctly.

Error handling is tested by confirming that the tool rejects dynamically linked binaries for both the test binary and k3s itself, and validates argument parsing rules like requiring basenames for manifest destinations and mandating the `--test-binary` flag. The tests use `debugfs` to inspect the resulting ext4 image and assert expected outcomes against standard output or error streams.