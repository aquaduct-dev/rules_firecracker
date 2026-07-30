#!/usr/bin/env bash
# mknoderootfs.sh — build the PRODUCTION ext4 node rootfs that a real openfactoryd
# node boots after being installed to disk from a USB stick.
#
# It is the real-hardware counterpart of mksystemdrootfs.sh (which builds a
# firecracker *test-rig* rootfs whose PID-1 runs ofd-rig.service orchestration and
# reads settings from the kernel cmdline). This image instead:
#   - boots a real Debian + systemd (PID 1),
#   - configures DHCP on wired NICs via systemd-networkd (real hardware, unlike
#     the rig's static ip= cmdline),
#   - runs ofd-provision.service (settings) then openfactoryd.service, which owns
#     k3s via systemctl exactly as in production,
#   - reads its config from /usr/local/etc/openfactory/settings.ini — the file the
#     installer injects into this rootfs at install time — so no kernel-cmdline or
#     exFAT-partition dependency at boot.
#
# The image is dd'd onto OFD_ROOTFS by openfactoryd-installer and booted via
# GRUB → fat-initrd (ofd.boot=disk switch_root) on real UEFI hardware. Keep the
# image ≤ the 4 GiB OFD_ROOTFS partition (see install/installer DefaultLayout).
#
# Args (all required unless noted):
#   --out PATH               Output ext4 image.
#   --k3s PATH               Static k3s binary        -> /usr/local/bin/k3s.
#   --openfactoryd PATH      openfactoryd daemon      -> /usr/local/bin/openfactoryd.
#   --service PATH           openfactoryd.service     -> /etc/systemd/system/, enabled.
#   --provision-script PATH  ofd-provision            -> /usr/local/sbin/ofd-provision.
#   --provision-unit PATH    ofd-provision.service    -> /etc/systemd/system/, enabled.
#   --nodewatch-script PATH  ofd-nodewatch            -> /usr/local/sbin/ofd-nodewatch.
#   --nodewatch-unit PATH    ofd-nodewatch.service    -> /etc/systemd/system/, enabled.
#   --size-mb N              ext4 size in MB (Debian ~120 + k3s ~70 + slack; 3000 safe).
#   --label STR              Filesystem label (max 16 chars, e.g. OFD_ROOTFS).
#   --base-tag TAG           docker image tag to build/reuse (default ofd-node-base).
set -euo pipefail
export PATH="/usr/sbin:/sbin:${PATH:-/usr/bin:/bin}"

OUT="" K3S="" OPENFACTORYD="" SERVICE="" PROV_SCRIPT="" PROV_UNIT="" NW_SCRIPT="" NW_UNIT="" SIZE_MB="" LABEL="" BASE_TAG="ofd-node-base"
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
    *) echo "mknoderootfs: unknown arg: $1" >&2; exit 2 ;;
  esac
done
for v in OUT K3S OPENFACTORYD SERVICE PROV_SCRIPT PROV_UNIT NW_SCRIPT NW_UNIT SIZE_MB LABEL; do
  eval "val=\${$v:-}"; [ -n "$val" ] || { echo "mknoderootfs: --${v,,} required" >&2; exit 2; }
done
command -v mkfs.ext4 >/dev/null || { echo "mknoderootfs: mkfs.ext4 not found (apt install e2fsprogs)" >&2; exit 1; }
command -v fakeroot  >/dev/null || { echo "mknoderootfs: fakeroot not found (apt install fakeroot)" >&2; exit 1; }
DOCKER="$(command -v docker || command -v podman || true)"
[ -n "$DOCKER" ] || { echo "mknoderootfs: docker/podman required for the systemd base image" >&2; exit 1; }

WORK="$(mktemp -d -t mknoderootfs.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
ROOT="$WORK/root"
mkdir -p "$ROOT"

# --- 1. Build (or reuse) the minimal Debian + systemd base image. ------------
# Unlike the rig image we KEEP systemd-networkd + its wait-online service (a real
# node uses DHCP, so openfactoryd After=network-online.target must actually wait
# for a lease). We still mask the getty/serial-getty units so systemd reaches
# multi-user under a serial console without hanging on ttyS0.device.
cat > "$WORK/Dockerfile" <<'DOCKER_EOF'
FROM debian:12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd systemd-sysv udev iproute2 iptables mount kmod ca-certificates \
      gawk hostname procps iputils-ping util-linux exfatprogs \
      wpasupplicant wireless-regdb iw \
    && rm -rf /var/lib/apt/lists/*
RUN for u in serial-getty@ttyS0.service getty@tty1.service getty.target \
             e2scrub_reap.service; do \
      ln -sf /dev/null /etc/systemd/system/$u; \
    done
# Keep kernel interface names (eth0) instead of systemd "predictable" names
# (enp0s3). openfactoryd detects the primary interface and configures k3s
# flannel-iface with that name (eth0); a udev rename to enp0s3 would leave
# flannel bound to a non-existent iface and the k3s agent/CNI never comes up.
# Masking the default .link disables the rename while keeping udev running (which
# systemd-networkd needs to manage the link for DHCP).
RUN ln -sf /dev/null /etc/systemd/network/99-default.link
# DHCP on any wired NIC via systemd-networkd.
RUN printf '[Match]\nName=en* eth*\n\n[Network]\nDHCP=yes\n' \
      > /etc/systemd/network/20-wired.network
# DHCP on wlan* too — ofd-provision writes the wpa_supplicant config + starts
# wpa_supplicant@wlan0 from the [wifi] section, and networkd DHCPs the link once
# it associates. (RequiredForOnline=no so a wired-only node doesn't wait on WiFi.)
RUN printf '[Match]\nName=wlan*\n\n[Network]\nDHCP=yes\n\n[Link]\nRequiredForOnline=no\n' \
      > /etc/systemd/network/25-wireless.network
RUN systemctl enable systemd-networkd.service \
 && systemctl enable systemd-networkd-wait-online.service
# Bound wait-online: return as soon as ANY link is online, cap at 20s, so a node
# with a slow/absent NIC still reaches multi-user instead of hanging forever.
RUN mkdir -p /etc/systemd/system/systemd-networkd-wait-online.service.d \
 && printf '[Service]\nExecStart=\nExecStart=/usr/lib/systemd/systemd-networkd-wait-online --any --timeout=20\n' \
      > /etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf
DOCKER_EOF
"$DOCKER" build -q -t "$BASE_TAG" -f "$WORK/Dockerfile" "$WORK" >/dev/null

# --- 2. Export the base image filesystem to a tar. ---------------------------
CID="$("$DOCKER" create "$BASE_TAG")"
"$DOCKER" export "$CID" -o "$WORK/base.tar"
"$DOCKER" rm "$CID" >/dev/null

# --- 3. Assemble + pack the rootfs under fakeroot (root-owned, no sudo). ------
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
  # kubectl/crictl/ctr convenience symlinks (k3s is multi-call), same as the rig.
  for tool in kubectl crictl ctr; do ln -sf k3s "$ROOT/usr/local/bin/$tool"; done
  # Enable openfactoryd + provisioning + readiness beacon at multi-user.
  mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants"
  for u in openfactoryd ofd-provision ofd-nodewatch; do
    ln -sf "/etc/systemd/system/$u.service" \
           "$ROOT/etc/systemd/system/multi-user.target.wants/$u.service"
  done
  # State dirs the daemon + k3s expect as REAL dirs.
  mkdir -p "$ROOT/var/lib/openfactoryd" "$ROOT/var/lib/rancher" \
           "$ROOT/usr/local/etc/openfactory" "$ROOT/etc/rancher"

  truncate -s "${SIZE_MB}M" "$OUT"
  mkfs.ext4 -F -q -L "$LABEL" -d "$ROOT" "$OUT" >/dev/null
'
echo "mknoderootfs: wrote $OUT ($(du -h "$OUT" | cut -f1))"
