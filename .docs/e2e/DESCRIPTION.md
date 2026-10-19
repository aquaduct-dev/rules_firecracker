<!-- docdaemon ts:2026-10-19T23:25:21Z hash:30e1310835b98f00 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains the Bazel build configuration and scripts for end-to-end smoke testing Firecracker microVMs.

## Overview
The `e2e/smoke` directory serves as an isolated test workspace to validate `rules_firecracker` from an external consumer's perspective. It ensures that label resolution, runfiles handling, and VM boot sequences function correctly outside the rules' own repository context. This setup also acts as the official BCR test module, verifying compatibility with standard Bazel environments.

## Deep Dive
### Build Targets
The `BUILD.bazel` file defines four primary targets. The `initrd` target packages `init.sh` into a minimal initial RAM filesystem using `firecracker_initramfs`. The `vm` target configures a microVM with 128 MiB memory and 2 vCPUs, attaching the initrd and resolving the kernel and Firecracker binary via default rules. The `boot_test` target executes this VM, expecting the output marker `E2E_SMOKE_OK nproc=2` to confirm successful boot. A fallback `firecracker_version_test` exists for environments lacking KVM support, validating the binary version via runfiles.

### Test Scripts
`init.sh` acts as PID 1 for the guest VM. It mounts the proc filesystem, counts available processors by parsing `/proc/cpuinfo`, and outputs a success marker before forcing a reboot. This minimal lifecycle proves the kernel can boot and access core resources. `firecracker_version_test.sh` verifies the presence of the pinned Firecracker binary. It locates the binary via Bazel runfiles using the `FC_RLOC` variable to avoid host PATH dependencies. The script runs `--version` once to minimize overhead and asserts the output matches the expected `Firecracker v*` prefix, preventing false positives from malformed output.

### Module Configuration
`MODULE.bazel` declares the `rules_firecracker_e2e_smoke` module. It imports `rules_firecracker` version `0.0.0` with a `local_path_override` pointing to the parent directory, allowing tests to use the local development version. It also includes `rules_shell` version `0.6.1` for shell utilities.

## Key Interfaces
- `:initrd`: Builds the initial RAM filesystem for the guest VM.
- `:vm`: Defines the virtual machine configuration (memory, CPUs, kernel).
- `:boot_test`: Executes the primary E2E boot verification test.
- `:firecracker_version_test`: Validates the Firecracker binary version in non-KVM environments.

## Dependencies
- `rules_firecracker`: Imported via `local_path_override` for local development validation.
- `rules_shell`: Provides shell utilities required by the test suite.

## Subcomponents
- `BUILD.bazel`: Bazel build definitions for targets.
- `MODULE.bazel`: Bazel module manifest and dependency configuration.
- `firecracker_version_test.sh`: Script to verify Firecracker binary version.
- `init.sh`: Entry point script for the e2e smoke microVM.