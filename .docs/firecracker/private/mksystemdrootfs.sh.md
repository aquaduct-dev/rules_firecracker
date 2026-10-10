<!-- docdaemon ts:2026-10-10T19:05:22Z hash:c9c51137ed622452 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds a minimal Debian-based ext4 rootfs containing systemd, k3s, and the openfactoryd rig for use in Firecracker VMs.

It orchestrates the creation of a lightweight base image using Docker or Podman, masking serial-getty units to prevent boot hangs on `ttyS0`. The script then exports this filesystem, layers in specific binaries (`k3s`, `openfactoryd`) and configuration files (rig scripts, systemd units), and packs everything into an ext4 image using `mkfs.ext4 -d` under `fakeroot`. This ensures all files are root-owned without requiring actual root privileges or mount operations during the build process.

The resulting image boots with `init=/sbin/init`, allowing systemd to manage the `ofd-rig.service` oneshot unit. This service drives the cluster orchestration by writing markers to the console, which `cluster_run.sh` later scrapes. The tool supports flexible argument injection for additional executables, files, and OCI images via repeatable flags, ensuring the rootfs contains exactly what is needed for the rig to function within the Firecracker environment.