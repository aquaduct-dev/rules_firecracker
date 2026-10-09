<!-- docdaemon ts:2026-10-09T22:28:56Z hash:2143f2ccd65e5ecd model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds a production-ready ext4 rootfs image for real-hardware OpenFactory nodes by packaging a minimal Debian base with specific systemd configurations and required binaries.

### Purpose
It creates the disk image (`OFD_ROOTFS`) that `openfactoryd-installer` writes to the target node's storage. Unlike the test-rig image, this rootfs relies on DHCP via `systemd-networkd` and reads configuration from `/usr/local/etc/openfactory/settings.ini` injected at install time, rather than kernel command-line arguments.

### Key Functions
*   **Base Image Construction**: Builds a Docker container (`ofd-node-base`) containing Debian 12 Slim, essential system utilities, and specific `systemd` overrides (masking serial gettys, disabling predictable interface names to preserve `eth0`, and configuring DHCP for wired/wireless interfaces).
*   **Filesystem Assembly**: Exports the Docker image filesystem and populates it with the provided `k3s` binary, `openfactoryd` daemon, and associated service units (`openfactoryd.service`, `ofd-provision.service`, `ofd-nodewatch.service`).
*   **Image Generation**: Uses `fakeroot` to create an ext4 image of the specified size and label, embedding the assembled directory structure directly into the filesystem metadata.

### Integration
This file is the counterpart to `mksystemdrootfs.sh`. It is invoked by the installer process to generate the bootable rootfs that GRUB loads via `fat-initrd` on UEFI hardware.