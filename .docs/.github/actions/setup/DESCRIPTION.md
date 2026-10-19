<!-- docdaemon ts:2026-10-19T23:24:42Z hash:95d826e43006404c model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This composite action configures the CI runner environment for Firecracker development, including package installation, KVM permissions, Bazel setup, and kernel cache restoration.

## Overview
The action prepares a GitHub Actions runner to build and test Firecracker VMs by ensuring the host has necessary build tools, granting the runner user access to `/dev/kvm`, and optimizing subsequent builds by caching Bazel outputs and prebuilt guest kernels. It serves as the foundational step for all CI jobs that require VM execution or compilation of the guest kernel.

## Deep Dive
### Host Dependencies
Installs `build-essential`, kernel headers (`libelf-dev`, `libssl-dev`), and filesystem utilities (`e2fsprogs`, `gdisk`) required for building the guest kernel and images.

### Bazel Sandbox Configuration
Disables `apparmor_restrict_unprivileged_userns` if present to allow Bazel's linux-sandbox to function correctly on Ubuntu 24.04 runners.

### KVM Access Control
Creates a udev rule (`99-kvm4all.rules`) to set `/dev/kvm` permissions to `0666`. The action reloads rules, triggers them with `--settle` to ensure application, and verifies read/write access immediately to fail fast if configuration fails. This prevents silent failures during VM tests due to permission issues.

### Build System Setup
Uses `bazel-contrib/setup-bazel` to install Bazelisk. It enables repository and disk caching at `/home/runner/.cache/fc-disk-cache` and sets common flags for color output and progress reporting.

### Kernel Caching
Restores the prebuilt guest kernel from the disk cache using a key derived from `.bazelversion`, `MODULE.bazel`, and kernel-specific build scripts/configs. This avoids rebuilding the kernel (~10-15 mins) unless source files change.

## Key Interfaces
*   **Inputs**: `kvm` (default: `true`) to enable KVM permission setup.
*   **Outputs**: `kernel-cache-hit` indicating if the kernel cache was restored successfully.

## Dependencies
*   `bazel-contrib/setup-bazel`
*   `build-essential`
*   `libelf-dev`
*   `libssl-dev`
*   `e2fsprogs`
*   `gdisk`

## Subcomponents
*   `action.yml`