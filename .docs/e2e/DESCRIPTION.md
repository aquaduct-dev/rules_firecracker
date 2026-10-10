<!-- docdaemon ts:2026-10-10T19:07:01Z hash:8596f71ea35765cd model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains the Bazel build configuration and scripts for end-to-end smoke testing Firecracker microVMs.

## Overview
The `e2e/smoke` directory provides an isolated environment to validate `rules_firecracker` from the perspective of an external consumer. It ensures that label resolution, runfiles handling, and VM booting work correctly outside the rules' own repository context. This setup also serves as the official test module for the Bazel Central Registry (BCR).

## Deep Dive
### Build Configuration
The test suite is orchestrated via `BUILD.bazel`, which defines targets for building an initial RAM filesystem (`initrd`) and a virtual machine configuration (`vm`). The `vm` target allocates 128 MiB of memory and provisions 2 vCPUs, attaching the minimal Linux environment provided by `init.sh`.

### Guest Initialization
The `init.sh` script acts as PID 1 within the guest. It mounts the `proc` filesystem, verifies CPU topology by counting processors in `/proc/cpuinfo`, and outputs a success marker (`E2E_SMOKE_OK`) to confirm the kernel booted successfully. Finally, it forces a reboot to terminate the test cleanly.

### Non-KVM Fallback
For environments lacking KVM hardware acceleration, such as BCR presubmits, the `firecracker_version_test` target runs a shell script to verify the pinned Firecracker binary's presence and version string using Bazel runfiles. This fallback ensures basic functionality checks pass even when full VM execution is impossible.

## Key Interfaces
*   `:initrd` - Builds the initial RAM filesystem with `init.sh` as the entry point.
*   `:vm` - Defines the microVM configuration with specific memory and CPU allocations.
*   `:boot_test` - Executes the primary E2E test, verifying successful boot and output markers.
*   `:firecracker_version_test` - Validates the Firecracker binary version in non-KVM environments.

## Dependencies
*   `rules_firecracker` (local development version)
*   `rules_shell` (version 0.6.1)

## Subcomponents
*   `BUILD.bazel`
*   `MODULE.bazel`
*   `firecracker_version_test.sh`
*   `init.sh`