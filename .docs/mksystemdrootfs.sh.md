<!-- docdaemon ts:2026-10-09T22:28:57Z hash:c9c51137ed622452 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds a minimal Debian-based ext4 rootfs containing systemd, k3s, and the openfactoryd rig for booting inside Firecracker.

## Purpose
It creates a hermetic root filesystem image that boots a real `systemd` instance (PID 1) rather than a static init script. This allows `openfactoryd` to manage `k3s` via standard `systemctl` commands within the VM environment.

## Key Functions
- **Base Image Construction**: Builds or reuses a `debian:12-slim` Docker image (`ofd-systemd-base`) with essential packages. It masks serial-getty and network wait units to prevent boot hangs on Firecracker's virtual TTY.
- **Rootfs Assembly**: Extracts the base image into a temporary directory. Installs binaries (`k3s`, `openfactoryd`, `ofd_rig.sh`) and configuration files at specified paths.
- **Filesystem Packaging**: Uses `fakeroot` to ensure all inodes are owned by root (uid/gid 0). It packs the directory tree into an ext4 image using `mkfs.ext4 -d`.

## Integration
The output image is consumed by `runner.sh.tpl` in rootfs mode. The `ofd-rig.service` unit is enabled in `multi-user.target.wants`, ensuring the orchestration script runs automatically at boot to initialize the cluster.