#!/usr/bin/env bash
# A generic stand-in for a real installer, driven by
# firecracker_install_cluster_test (run as root via sudo):
#   installer.sh --settings settings.ini --rootfs-image root.ext4
# Partitions [install] target_disk as GPT (1: 8 MiB ESP, 2: OFD_ROOTFS),
# injects cluster_secret into a copy of the rootfs image and writes it to
# partition 2.
set -euo pipefail
export PATH="/usr/local/sbin:/usr/sbin:/sbin:${PATH:-/usr/bin:/bin}"

SETTINGS="" ROOTFS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --settings)     SETTINGS="$2"; shift 2 ;;
    --rootfs-image) ROOTFS="$2";   shift 2 ;;
    *) echo "installer: unknown arg $1" >&2; exit 2 ;;
  esac
done
ini() { sed -n "s/^$1[[:space:]]*=[[:space:]]*//p" "$SETTINGS" | head -n1; }
DISK="$(ini target_disk)"
SECRET="$(ini cluster_secret)"
[ "$(ini wipe_confirm)" = yes-i-am-sure ] || { echo "installer: wipe not confirmed" >&2; exit 1; }
[ -b "$DISK" ] || { echo "installer: $DISK is not a block device" >&2; exit 1; }

sgdisk --zap-all "$DISK" >/dev/null
sgdisk -n 1:2048:+8M -t 1:ef00 -c 1:EFI -n 2:0:0 -t 2:8300 -c 2:OFD_ROOTFS "$DISK" >/dev/null
START="$(sgdisk -i 2 "$DISK" | sed -n 's/^First sector: \([0-9]*\).*/\1/p')"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cp "$ROOTFS" "$WORK/root.ext4"; chmod u+w "$WORK/root.ext4"
printf 'cluster_secret=%s\n' "$SECRET" >"$WORK/settings"
debugfs -w -R "write $WORK/settings /etc/installed-settings" "$WORK/root.ext4" >/dev/null 2>&1
dd if="$WORK/root.ext4" of="$DISK" bs=1M oflag=seek_bytes seek=$((START * 512)) conv=notrunc,fsync status=none
echo "installer: wrote rootfs to $DISK partition 2 (sector $START)"
