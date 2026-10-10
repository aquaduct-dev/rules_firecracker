<!-- docdaemon ts:2026-10-10T19:05:20Z hash:2143f2ccd65e5ecd model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script builds a production-ready ext4 rootfs image for real-hardware nodes, incorporating Debian systemd, k3s, and OpenFactory services.

## Purpose
It creates the disk image (`OFD_ROOTFS`) that a node boots from after installation via USB. Unlike the Firecracker test rig, this image supports DHCP networking and reads configuration from `/usr/local/etc/openfactory/settings.ini` injected at install time.

## Key Functions
- **Base Image Construction**: Builds a minimal `debian:12-slim` container with systemd, networkd, and necessary utilities. It masks serial consoles to prevent boot hangs and configures DHCP for wired/wireless interfaces.
- **Service Assembly**: Exports the base filesystem and installs binaries (`k3s`, `openfactoryd`) and systemd units (`ofd-provision`, `ofd-nodewatch`).
- **Image Generation**: Uses `fakeroot` to pack the assembled directory tree into an ext4 image of specified size and label.

## Integration
The output is consumed by `openfactoryd-installer`, which writes it to the target partition. The node then boots via GRUB/fat-initrd, executing `rootfs` to start the production daemon stack.