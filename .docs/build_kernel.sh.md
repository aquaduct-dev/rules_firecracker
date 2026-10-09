<!-- docdaemon ts:2026-10-09T22:29:00Z hash:8930c96e694b972e model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds a firecracker-compatible uncompressed `vmlinux` ELF from a pinned Linux source tarball and configuration.

### Purpose
The script automates the compilation of the Linux kernel into an uncompressed ELF binary suitable for direct booting by Firecracker. It is designed to be executed within a Bazel `genrule` using the host toolchain, ensuring reproducible builds without requiring module signing keys or BTF debugging tools.

### Key Functions
- **Argument Parsing**: Accepts paths for the source tarball (`.tar.xz`), the `.config` file, and the output destination via `--tarball`, `--config`, and `--out`. Supports parallelism control via `--jobs`.
- **Environment Setup**: Extracts the source tarball into a temporary directory (`WORK`) and cleans it up on exit. Resolves all input/output paths to absolute values before changing directories.
- **Configuration Application**: Copies the provided `.config` into the source tree and runs `make olddefconfig` to handle any version drift between the source code and the configuration file.
- **Build Execution**: Invokes `make vmlinux` with the specified job count to produce the final ELF binary, which is then copied to the output path.

### Integration
This script serves as the bridge between Bazel's build system and the raw Linux kernel source. By disabling `CONFIG_MODULES` and `CONFIG_DEBUG_INFO_BTF` in the pinned config, it minimizes dependencies (removing the need for `pahole` or key management) and ensures a lightweight, static kernel image.