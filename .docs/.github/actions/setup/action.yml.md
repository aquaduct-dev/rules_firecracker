<!-- docdaemon ts:2026-10-19T23:24:29Z hash:9bf87c8ab1ceb8f7 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This composite action configures the CI runner environment for Firecracker development, including package installation, KVM permissions, Bazel setup, and kernel cache restoration.

### Purpose
The action prepares a GitHub Actions runner to build and test Firecracker VMs. It ensures the host has necessary build tools, grants the runner user access to `/dev/kvm`, and optimizes subsequent builds by caching Bazel outputs and prebuilt guest kernels.

### Key Steps

1.  **Host Packages**: Installs `build-essential`, kernel headers (`libelf-dev`, `libssl-dev`), and filesystem utilities (`e2fsprogs`, `gdisk`) required for building the guest kernel and images.
2.  **Bazel Sandbox**: Disables `apparmor_restrict_unprivileged_userns` if present, allowing Bazel's linux-sandbox to function on Ubuntu 24.04.
3.  **KVM Access**: Creates a udev rule (`99-kvm4all.rules`) to set `/dev/kvm` permissions to `0666`. It reloads rules, triggers them with `--settle` to ensure application, and verifies read/write access immediately to fail fast if configuration fails.
4.  **Bazel Setup**: Uses `bazel-contrib/setup-bazel` to install Bazelisk. It enables repository and disk caching (`/home/runner/.cache/fc-disk-cache`) and sets common flags for color output and progress reporting.
5.  **Kernel Cache**: Restores the prebuilt guest kernel from the disk cache using a key derived from `.bazelversion`, `MODULE.bazel`, and kernel-specific build scripts/configs. This avoids rebuilding the kernel (~10-15 mins) unless source files change.

### Inputs & Outputs
*   **`kvm`** (default: `true`): Enables the KVM permission setup step.
*   **`kernel-cache-hit`**: Output indicating if the kernel cache was restored successfully.