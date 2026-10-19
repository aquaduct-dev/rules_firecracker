<!-- docdaemon ts:2026-10-10T19:05:33Z hash:8af7a1ff44da50f2 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This GitHub Actions composite action configures the CI runner environment for building and testing Firecracker.

## Overview
The `setup` action prepares the Ubuntu 24.04 runner for `rules_firecracker` by installing build dependencies, enabling unprivileged user namespaces for Bazel's linux-sandbox, configuring `/dev/kvm` permissions, and setting up Bazelisk with repository and disk caching. It also restores a prebuilt guest kernel from cache to speed up CI runs. This ensures a consistent and optimized environment for all subsequent test and build steps in the pipeline.

## Deep Dive
### Package Installation
Installs the packages for building the guest kernel (`build-essential`, `flex`, `bison`, `bc`, `libelf-dev`, `libssl-dev`), for making images (`e2fsprogs`), for the install-to-disk rig (`gdisk`, `dosfstools`, `exfatprogs`), and `util-linux` and `iproute2` for block devices and the cluster tests' bridge and TAP networking.

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
- Host packages: build-essential, flex, bison, bc, libelf-dev, libssl-dev, e2fsprogs, gdisk, dosfstools, exfatprogs, util-linux, iproute2

## Subcomponents
- action.yml