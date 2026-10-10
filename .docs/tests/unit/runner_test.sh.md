<!-- docdaemon ts:2026-10-10T19:05:23Z hash:518577a01176c186 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file is a unit test suite for the Firecracker microVM launcher, verifying configuration generation and runtime behavior without requiring KVM.

It exercises the `runner.sh.tpl` script by injecting a fake Firecracker binary that dumps the generated `vm.json`. The tests cover two primary boot modes: **initrd** (kernel + initramfs) and **rootfs** (direct disk boot). Key scenarios include validating machine configuration (vCPU count, memory), attaching extra drives, configuring networking via `FC_TAP` and `FC_GUEST_MAC`, and handling persistent disks.

The suite also validates environment variable overrides such as `FC_FIRECRACKER` for custom binaries, `FC_TIMEOUT` for process lifecycle management, and `FC_KEEP_WORK` for debugging. It ensures that path resolution works correctly with both absolute and relative `RUNFILES_DIR` paths, confirming that no host PATH lookups occur for internal resources.