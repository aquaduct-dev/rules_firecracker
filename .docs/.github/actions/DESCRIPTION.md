<!-- docdaemon ts:2026-10-10T19:05:44Z hash:81a2043c04e0fe6e model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This GitHub Actions composite action configures the CI runner environment for building and testing Firecracker.

## Overview
The `setup` action prepares the Ubuntu 24.04 runner for `rules_firecracker` by installing build dependencies, enabling unprivileged user namespaces for Bazel's linux-sandbox, configuring `/dev/kvm` permissions, and setting up Bazelisk with repository and disk caching. It also restores a prebuilt guest kernel from cache to speed up CI runs. This ensures a consistent and optimized environment for all subsequent test and build steps in the pipeline.

## Deep Dive
### Package Installation
Installs essential tools required for kernel building, such as `build-essential`, `flex`, and `bison`. It also includes utilities for disk image manipulation like `e2fsprogs` and `gdisk`. These packages are critical for compiling the guest kernel and managing block devices during tests.

### Sandbox Configuration
Disables AppArmor restrictions on unprivileged user namespaces if the profile is present. This step is necessary to allow Bazel's `linux-sandbox` to function correctly within the containerized or restricted CI environment. Without this adjustment, sandboxed builds would fail due to permission denied errors.

### KVM Access
Creates a udev rule to grant the runner user read/write access to `/dev/kvm`. This configuration is conditional based on the `kvm` input, which defaults to `true`. Proper KVM access is vital for running virtual machine-based tests efficiently.

### Bazel Setup
Utilizes `bazel-contrib/setup-bazel` to install Bazelisk, enable repository caching, and configure a persistent disk cache at `~/.cache/fc-disk-cache`. This cache stores the prebuilt guest kernel, significantly reducing build times across CI runs.

### Kernel Cache Restoration
Restores the guest kernel disk cache using a key derived from relevant source files. This ensures that the cached kernel remains consistent with the current codebase state, preventing mismatches between the build artifacts and the source code.

## Key Interfaces
- Composite Action Input: `kvm` (boolean, default: true) - Controls whether to configure KVM access.

## Dependencies
- bazel-contrib/setup-bazel
- Ubuntu 24.04 runner environment
- Build dependencies: build-essential, flex, bison, e2fsprogs, gdisk

## Subcomponents
- action.yml