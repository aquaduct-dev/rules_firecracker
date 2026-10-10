<!-- docdaemon ts:2026-10-10T19:04:53Z hash:469ebfd95f81428d model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds an uncompressed vmlinux ELF kernel image compatible with Firecracker from a pinned source tarball and configuration.

### Purpose
The script automates the compilation of a Linux kernel specifically tailored for Firecracker. It ensures reproducibility by pinning build metadata and disabling features like module loading and BTF debug info, which are unnecessary for the microVM use case. It is designed to be executed within a Bazel `genrule` using the host toolchain.

### Key Functions
- **Argument Parsing**: Accepts paths for the source tarball, `.config`, output file, and optional parallel job count (`--jobs`).
- **Environment Setup**: Extracts the source tarball into a temporary directory, applies the provided `.config`, and runs `make olddefconfig` to handle any version drift between the source and config.
- **Build Execution**: Sets `KBUILD_BUILD_TIMESTAMP` and user/host variables to ensure deterministic builds. Compiles the kernel using `make vmlinux`.
- **Cleanup**: Copies the resulting `vmlinux` to the specified output path and removes the temporary working directory upon exit.

### Integration
This script serves as the bridge between Bazel's dependency management (providing the pinned tarball and config) and the actual kernel compilation process. It outputs a single ELF binary that Firecracker can boot directly.