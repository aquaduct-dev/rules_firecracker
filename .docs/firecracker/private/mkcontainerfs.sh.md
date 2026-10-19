<!-- docdaemon ts:2026-10-19T23:24:29Z hash:83b4049ae9de31c6 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script converts an OCI image layout into a bootable ext4 rootfs for Firecracker, replacing the container's init process with a minimal shell that mounts virtual filesystems and executes the image entrypoint.

It parses `index.json` to resolve layer digests and config blobs using Python, then iterates through layers to materialize the filesystem. It handles AUFS-style whiteouts (`.wh.*`) to correctly apply file deletions and opaque directories during the merge.

The script validates that the provided BusyBox binary is statically linked ELF, ensuring it runs without external dependencies in the guest kernel. It generates `/sbin/init` by combining the image's `Env`, `Entrypoint`, and `Cmd` with any `--extra-env` or `--extra-arg` overrides, creating a self-contained PID 1 that mounts `/proc`, `/sys`, and `/dev`.

After formatting the ext4 image with `mkfs.ext4 -d`, it uses `debugfs` to re-own all inodes to root (0:0). This step was introduced to fix issues where files were owned by the build user due to `mkfs.ext4` copying ownership from the staging tree, which caused permission errors in the unprivileged guest environment.