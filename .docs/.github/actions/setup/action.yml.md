<!-- docdaemon ts:2026-10-10T19:04:45Z hash:3f5c923211c36098 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This GitHub Actions composite action configures the CI runner environment for building and testing Firecracker, including package installation, KVM access, Bazel setup, and kernel cache restoration.

### Purpose
The `setup` action prepares the Ubuntu 24.04 runner for `rules_firecracker` by installing build dependencies, enabling unprivileged user namespaces for Bazel's linux-sandbox, configuring `/dev/kvm` permissions, and setting up Bazelisk with repository and disk caching. It also restores a prebuilt guest kernel from cache to speed up CI runs.

### Key Functions
- **Package Installation**: Installs essential tools for kernel building (`build-essential`, `flex`, `bison`, etc.) and disk image utilities (`e2fsprogs`, `gdisk`, etc.).
- **Sandbox Configuration**: Disables AppArmor restrictions on unprivileged user namespaces if present, allowing Bazel's sandbox to function correctly.
- **KVM Access**: Creates a udev rule to grant the runner user read/write access to `/dev/kvm`. This step is conditional based on the `kvm` input (default: `true`).
- **Bazel Setup**: Uses `bazel-contrib/setup-bazel` to install Bazelisk, enable repository caching, and configure a persistent disk cache at `~/.cache/fc-disk-cache` for the prebuilt guest kernel.
- **Kernel Cache Restoration**: Restores the guest kernel disk cache using a key derived from relevant source files to ensure consistency across changes.