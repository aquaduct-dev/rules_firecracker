#!/usr/bin/env bash
# mksystemdrootfs.sh — build an ext4 rootfs that boots a REAL systemd (PID 1)
# inside firecracker and runs a k3s cluster that openfactoryd OWNS via systemctl.
#
# This is the systemd counterpart of mkk3srootfs.sh (which builds a hand-rolled
# static-busybox rootfs whose /sbin/init is a shell script). openfactoryd no
# longer execs k3s as a child — it writes /etc/rancher/k3s/config.yaml + a
# k3s.service unit and drives it with systemctl — so the rig must boot a real
# service manager. The base OS is a minimal Debian + systemd image built with
# docker/podman (the ONLY non-hermetic step; these rigs already run local + sudo
# + kvm). The bazel-built binaries (k3s, openfactoryd, wgsniff, the rig
# orchestration + its systemd unit) are layered in AFTER, and the whole image is
# packed to ext4 with `mkfs.ext4 -d` under fakeroot — so files stay root-owned
# with NO mount and NO sudo, exactly like mkk3srootfs.sh.
#
# Boot contract (matches runner.sh.tpl rootfs mode + the ofd_cluster_vm cmdline):
#   root=/dev/vda, init=/sbin/init  (Debian's /sbin/init IS systemd)
# The serial-getty units are masked in the base image so systemd does not hang
# forever on dev-ttyS0.device (a firecracker quirk) — it reaches multi-user in
# ~0.5s. The rig orchestration runs as the ofd-rig.service oneshot, which writes
# the OFD_* markers to /dev/console (ttyS0) that cluster_run.sh scrapes.
#
# Args:
#   --out PATH               Output ext4 image.
#   --k3s PATH               Static k3s binary -> /usr/local/bin/k3s.
#   --openfactoryd PATH      openfactoryd daemon -> /usr/local/bin/openfactoryd.
#   --rig-script PATH        Rig orchestration -> /usr/local/bin/ofd_rig.sh (0755).
#   --rig-unit PATH          systemd unit -> /etc/systemd/system/ofd-rig.service,
#                            enabled in multi-user.target.wants.
#   --size-mb N              ext4 size in MB (Debian base ~120 MiB + k3s ~70 MiB
#                            + runtime unpack ~150 MiB + images; 2400 is safe).
#   --label STR              Filesystem label (max 16 chars).
#   --base-tag TAG           docker image tag to build/reuse (default ofd-systemd-base).
# Repeatable:
#   --exec SRC=DST           Copy SRC to DST in the rootfs at 0755.
#   --file SRC=DST           Copy SRC to DST in the rootfs at 0644.
#   --image SRC=DST          Copy SRC to /etc/images/DST (OCI tarball the rig
#                            preloads into k3s' embedded containerd).
set -euo pipefail
export PATH="/usr/sbin:/sbin:${PATH:-/usr/bin:/bin}"

OUT="" K3S="" OPENFACTORYD="" RIG_SCRIPT="" RIG_UNIT="" SIZE_MB="" LABEL="" BASE_TAG="ofd-systemd-base"
EXECS=() FILES=() IMAGES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --out)          OUT="$2";          shift 2 ;;
    --k3s)          K3S="$2";          shift 2 ;;
    --openfactoryd) OPENFACTORYD="$2"; shift 2 ;;
    --rig-script)   RIG_SCRIPT="$2";   shift 2 ;;
    --rig-unit)     RIG_UNIT="$2";     shift 2 ;;
    --size-mb)      SIZE_MB="$2";      shift 2 ;;
    --label)        LABEL="$2";        shift 2 ;;
    --base-tag)     BASE_TAG="$2";     shift 2 ;;
    --exec)         EXECS+=("$2");     shift 2 ;;
    --file)         FILES+=("$2");     shift 2 ;;
    --image)        IMAGES+=("$2");    shift 2 ;;
    *) echo "mksystemdrootfs: unknown arg: $1" >&2; exit 2 ;;
  esac
done
for v in OUT K3S OPENFACTORYD RIG_SCRIPT RIG_UNIT SIZE_MB LABEL; do
  eval "val=\${$v:-}"; [ -n "$val" ] || { echo "mksystemdrootfs: --${v,,} required" >&2; exit 2; }
done
command -v mkfs.ext4 >/dev/null || { echo "mksystemdrootfs: mkfs.ext4 not found (apt install e2fsprogs)" >&2; exit 1; }
command -v fakeroot  >/dev/null || { echo "mksystemdrootfs: fakeroot not found (apt install fakeroot)" >&2; exit 1; }
DOCKER="$(command -v docker || command -v podman || true)"
[ -n "$DOCKER" ] || { echo "mksystemdrootfs: docker/podman required for the systemd base image" >&2; exit 1; }

WORK="$(mktemp -d -t mksystemdrootfs.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
ROOT="$WORK/root"
mkdir -p "$ROOT"

# --- 1. Build (or reuse) the minimal Debian + systemd base image. ------------
# Masking the serial-getty/networkd-wait units at build time is what lets systemd
# reach multi-user under firecracker (else it blocks forever on dev-ttyS0.device).
cat > "$WORK/Dockerfile" <<'DOCKER_EOF'
FROM debian:12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd systemd-sysv iproute2 iptables mount kmod ca-certificates \
      gawk hostname wget procps iputils-ping \
    && rm -rf /var/lib/apt/lists/*
RUN for u in serial-getty@ttyS0.service getty@tty1.service getty.target \
             systemd-networkd-wait-online.service systemd-resolved.service \
             e2scrub_reap.service; do \
      ln -sf /dev/null /etc/systemd/system/$u; \
    done
DOCKER_EOF
"$DOCKER" build -q -t "$BASE_TAG" -f "$WORK/Dockerfile" "$WORK" >/dev/null

# --- 2. Export the base image filesystem to a tar. ---------------------------
CID="$("$DOCKER" create "$BASE_TAG")"
"$DOCKER" export "$CID" -o "$WORK/base.tar"
"$DOCKER" rm "$CID" >/dev/null

# --- 3. Assemble + pack the rootfs under fakeroot (root-owned, no sudo). ------
# Everything that touches ownership/permissions runs inside one fakeroot so the
# ext4 inodes end up uid:gid 0:0.
export OUT K3S OPENFACTORYD RIG_SCRIPT RIG_UNIT SIZE_MB LABEL ROOT WORK
EXEC_SPECS="${EXECS[*]:-}" FILE_SPECS="${FILES[*]:-}" IMAGE_SPECS="${IMAGES[*]:-}"
export EXEC_SPECS FILE_SPECS IMAGE_SPECS
fakeroot bash -eu -c '
  # Extract the Debian base (device nodes are recreated by systemd via devtmpfs;
  # under fakeroot tar still records the tar owners = root).
  tar -xf "$WORK/base.tar" -C "$ROOT" 2>/dev/null || true

  install -D -m0755 "$K3S"          "$ROOT/usr/local/bin/k3s"
  install -D -m0755 "$OPENFACTORYD" "$ROOT/usr/local/bin/openfactoryd"
  install -D -m0755 "$RIG_SCRIPT"   "$ROOT/usr/local/bin/ofd_rig.sh"
  install -D -m0644 "$RIG_UNIT"     "$ROOT/etc/systemd/system/ofd-rig.service"
  # Enable the rig oneshot so systemd starts it at multi-user.
  mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants"
  ln -sf /etc/systemd/system/ofd-rig.service \
         "$ROOT/etc/systemd/system/multi-user.target.wants/ofd-rig.service"
  # App state dirs the rig + openfactoryd expect as REAL dirs.
  mkdir -p "$ROOT/var/lib/openfactoryd" "$ROOT/var/lib/rancher" \
           "$ROOT/usr/local/etc/openfactory" "$ROOT/etc/images"

  for spec in $EXEC_SPECS; do
    src="${spec%%=*}"; dst="${spec#*=}"
    case "$dst" in /*) ;; *) echo "mksystemdrootfs: --exec dst must be absolute: $spec" >&2; exit 2 ;; esac
    install -D -m0755 "$src" "$ROOT$dst"
  done
  for spec in $FILE_SPECS; do
    src="${spec%%=*}"; dst="${spec#*=}"
    case "$dst" in /*) ;; *) echo "mksystemdrootfs: --file dst must be absolute: $spec" >&2; exit 2 ;; esac
    install -D -m0644 "$src" "$ROOT$dst"
  done
  for spec in $IMAGE_SPECS; do
    src="${spec%%=*}"; dst="${spec#*=}"
    case "$dst" in */*) echo "mksystemdrootfs: --image dst must be a basename: $spec" >&2; exit 2 ;; esac
    install -D -m0644 "$src" "$ROOT/etc/images/$dst"
  done

  truncate -s "${SIZE_MB}M" "$OUT"
  mkfs.ext4 -F -q -L "$LABEL" -d "$ROOT" "$OUT" >/dev/null
'
echo "mksystemdrootfs: wrote $OUT ($(du -h "$OUT" | cut -f1))"
