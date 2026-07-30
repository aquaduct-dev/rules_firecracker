#!/usr/bin/env bash
# mknodeimage.sh — build a SELF-CONTAINED Debian node image for openfactoryd.
#
# Unlike the old mknoderootfs.sh (a minimal rootfs that booted the BUILD HOST's
# kernel via a fat-initrd switch_root, with modules/firmware/udev/wpa_supplicant
# hand-injected), this is a conventional bootable system:
#   - its OWN Debian kernel (linux-image-amd64) + initramfs (initramfs-tools),
#   - linux-firmware for broad wired/WiFi hardware,
#   - NetworkManager for wired + WiFi (creds applied by ofd-provision from
#     the [wifi] section of settings.ini),
#   - systemd, k3s, openfactoryd.
# It boots by GRUB loading /boot/vmlinuz + /boot/initrd.img straight off this
# rootfs (root=LABEL=OFD_ROOTFS) — no host kernel, no per-capability patching.
#
# Args (all required unless noted):
#   --out PATH               Output ext4 image.
#   --k3s PATH               Static k3s binary   -> /usr/local/bin/k3s.
#   --openfactoryd PATH      openfactoryd daemon -> /usr/local/bin/openfactoryd.
#   --service PATH           openfactoryd.service -> enabled.
#   --provision-script PATH  ofd-provision  -> /usr/local/sbin/, unit enabled.
#   --provision-unit PATH    ofd-provision.service.
#   --nodewatch-script PATH  ofd-nodewatch  -> /usr/local/sbin/, unit enabled.
#   --nodewatch-unit PATH    ofd-nodewatch.service.
#   --size-mb N              ext4 size in MB (Debian+kernel+firmware ~1.4G; 3500 safe).
#   --label STR              Filesystem label (OFD_ROOTFS).
#   --base-tag TAG           docker image tag (default ofd-node-image).
set -euo pipefail
export PATH="/usr/sbin:/sbin:${PATH:-/usr/bin:/bin}"

OUT="" K3S="" OPENFACTORYD="" SERVICE="" PROV_SCRIPT="" PROV_UNIT="" NW_SCRIPT="" NW_UNIT="" SIZE_MB="" LABEL="" BASE_TAG="ofd-node-image"
while [ $# -gt 0 ]; do
  case "$1" in
    --out)              OUT="$2";          shift 2 ;;
    --k3s)              K3S="$2";          shift 2 ;;
    --openfactoryd)     OPENFACTORYD="$2"; shift 2 ;;
    --service)          SERVICE="$2";      shift 2 ;;
    --provision-script) PROV_SCRIPT="$2";  shift 2 ;;
    --provision-unit)   PROV_UNIT="$2";    shift 2 ;;
    --nodewatch-script) NW_SCRIPT="$2";    shift 2 ;;
    --nodewatch-unit)   NW_UNIT="$2";      shift 2 ;;
    --size-mb)          SIZE_MB="$2";      shift 2 ;;
    --label)            LABEL="$2";        shift 2 ;;
    --base-tag)         BASE_TAG="$2";     shift 2 ;;
    *) echo "mknodeimage: unknown arg: $1" >&2; exit 2 ;;
  esac
done
for v in OUT K3S OPENFACTORYD SERVICE PROV_SCRIPT PROV_UNIT NW_SCRIPT NW_UNIT SIZE_MB LABEL; do
  eval "val=\${$v:-}"; [ -n "$val" ] || { echo "mknodeimage: --${v,,} required" >&2; exit 2; }
done
command -v mkfs.ext4 >/dev/null || { echo "mknodeimage: mkfs.ext4 not found" >&2; exit 1; }
command -v fakeroot  >/dev/null || { echo "mknodeimage: fakeroot not found" >&2; exit 1; }
DOCKER="$(command -v docker || command -v podman || true)"
[ -n "$DOCKER" ] || { echo "mknodeimage: docker/podman required" >&2; exit 1; }

WORK="$(mktemp -d -t mknodeimage.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
ROOT="$WORK/root"
mkdir -p "$ROOT"

# --- 1. Build (or reuse) the self-contained Debian image. --------------------
# non-free-firmware gives us linux-firmware; a real kernel + initramfs-tools make
# it boot on its own. NetworkManager handles wired + WiFi. The label is baked in
# so GRUB + the kernel find root=LABEL. /boot/vmlinuz + /boot/initrd.img stable
# symlinks let the installer's grub.cfg reference a fixed path.
cat > "$WORK/Dockerfile" <<DOCKER_EOF
FROM debian:12-slim
RUN sed -i 's/ main/ main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources 2>/dev/null || \
    sed -i 's/ main/ main contrib non-free non-free-firmware/' /etc/apt/sources.list 2>/dev/null || true
RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd systemd-sysv udev dbus \
      linux-image-amd64 initramfs-tools \
      firmware-linux-free firmware-iwlwifi firmware-realtek firmware-atheros \
      firmware-misc-nonfree firmware-brcm80211 \
      network-manager iproute2 iptables kmod ca-certificates \
      gawk hostname procps iputils-ping util-linux exfatprogs e2fsprogs \
    && rm -rf /var/lib/apt/lists/*
# Serial console usable; don't let systemd hang on a missing display.
RUN systemctl enable NetworkManager 2>/dev/null || true
# Set the fs label into fstab-free boot: the installer's grub.cfg passes
# root=LABEL=${LABEL}; NetworkManager is the netdev renderer. Provide stable
# /boot symlinks for grub.cfg (Debian names files vmlinuz-<ver>).
RUN set -e; kver=\$(ls /lib/modules | head -1); \
    ln -sf "vmlinuz-\$kver"    /boot/vmlinuz; \
    ln -sf "initrd.img-\$kver" /boot/initrd.img
# fstab so systemd remounts / read-write on boot (the installer boots root=… rw,
# but this keeps a clean-mount + fsck contract and matches a normal install).
RUN printf 'LABEL=${LABEL} / ext4 errors=remount-ro 0 1\n' > /etc/fstab
DOCKER_EOF
"$DOCKER" build -q -t "$BASE_TAG" -f "$WORK/Dockerfile" "$WORK" >/dev/null

# --- 2. Export the base filesystem. ------------------------------------------
CID="$("$DOCKER" create "$BASE_TAG")"
"$DOCKER" export "$CID" -o "$WORK/base.tar"
"$DOCKER" rm "$CID" >/dev/null

# --- 3. Layer the openfactoryd payload + pack to ext4 under fakeroot. ---------
export OUT K3S OPENFACTORYD SERVICE PROV_SCRIPT PROV_UNIT NW_SCRIPT NW_UNIT SIZE_MB LABEL ROOT WORK
fakeroot bash -eu -c '
  tar -xf "$WORK/base.tar" -C "$ROOT" 2>/dev/null || true

  install -D -m0755 "$K3S"          "$ROOT/usr/local/bin/k3s"
  install -D -m0755 "$OPENFACTORYD" "$ROOT/usr/local/bin/openfactoryd"
  install -D -m0755 "$PROV_SCRIPT"  "$ROOT/usr/local/sbin/ofd-provision"
  install -D -m0755 "$NW_SCRIPT"    "$ROOT/usr/local/sbin/ofd-nodewatch"
  install -D -m0644 "$SERVICE"      "$ROOT/etc/systemd/system/openfactoryd.service"
  install -D -m0644 "$PROV_UNIT"    "$ROOT/etc/systemd/system/ofd-provision.service"
  install -D -m0644 "$NW_UNIT"      "$ROOT/etc/systemd/system/ofd-nodewatch.service"
  for tool in kubectl crictl ctr; do ln -sf k3s "$ROOT/usr/local/bin/$tool"; done
  mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants"
  for u in openfactoryd ofd-provision ofd-nodewatch; do
    ln -sf "/etc/systemd/system/$u.service" \
           "$ROOT/etc/systemd/system/multi-user.target.wants/$u.service"
  done
  mkdir -p "$ROOT/var/lib/openfactoryd" "$ROOT/var/lib/rancher" \
           "$ROOT/usr/local/etc/openfactory" "$ROOT/etc/rancher"

  truncate -s "${SIZE_MB}M" "$OUT"
  mkfs.ext4 -F -q -L "$LABEL" -d "$ROOT" "$OUT" >/dev/null
'
echo "mknodeimage: wrote $OUT ($(du -h "$OUT" | cut -f1)); kernel $(ls "$ROOT"/lib/modules 2>/dev/null | head -1)"
