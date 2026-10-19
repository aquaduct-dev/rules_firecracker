<!-- docdaemon ts:2026-10-19T23:24:36Z hash:af1b161d34954a03 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script validates that `mkcontainerfs` correctly flattens a multi-layer OCI image layout into an ext4 filesystem, handling whiteouts, opaque directories, and init generation.

The test constructs a three-layer OCI layout in `$T/layout` with specific file operations:
- **Layer 1**: Adds files (`/app/run.sh`, `/app/old.txt`) and an opaque directory (`/etc/opaque`).
- **Layer 2**: Whiteouts `/app/old.txt` (file deletion) and marks `/etc/opaque` as opaque (hiding previous contents), then adds new files (`b.txt`, `c.txt`).
- **Layer 3**: Whiteouts `/etc/opaque/c.txt` to verify selective deletion within opaque directories.

It invokes `mkcontainerfs` with this layout, a busybox binary, and extra environment arguments, then verifies the resulting `ext4` image using `debugfs`:
- Confirms whiteouts are applied (files removed).
- Confirms opaque directory semantics (previous files hidden, new ones visible).
- Ensures no `.wh.` markers leak into the final filesystem.
- Checks `/sbin/init` content for correct environment variable ordering (extra env overrides image env), working directory changes, and command execution.
- Verifies file ownership is root (0:0) and permissions are correct.

Finally, it tests error cases: rejecting images with no Entrypoint/Cmd and invalid `--extra-env` syntax.