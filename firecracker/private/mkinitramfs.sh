#!/usr/bin/env bash
# mkinitramfs.sh — pack a cpio+gzip initramfs from a set of files.
#
# Args (all required unless marked):
#   --out PATH               Output cpio.gz file.
#   --busybox PATH           Statically-linked busybox; symlinked into
#                            /bin for every applet plus /sbin/{init,
#                            mount,umount,sh}.
#   --init PATH              Source of /init (PID 1). Installed 0755.
# Repeatable:
#   --file SRC=DST           Copy SRC to DST inside the cpio at 0644.
#   --exec SRC=DST           Copy SRC to DST inside the cpio at 0755.
#                            ELF entries are checked for static linkage
#                            (initramfs has no libc).

set -euo pipefail

# --- ELF helpers (coreutils `od` only; no libmagic `file`) ---------------
# is_elf FILE: true iff FILE starts with the ELF magic.
is_elf() { [ "$(od -An -c -N4 "$1" 2>/dev/null | tr -d ' ')" = '177ELF' ]; }
# elf_is_dynamic FILE: true iff the ELF has a PT_INTERP program header, i.e.
# needs a dynamic loader + libc at runtime. Static and static-pie binaries
# have none. Little-endian ELF only (x86_64, aarch64).
elf_is_dynamic() {
  local f="$1" cls phoff phentsize phnum i type
  rd() { od --endian=little -An -t "u$2" -j "$1" -N "$2" "$f" | tr -d ' '; }
  cls="$(rd 4 1)"
  if [ "$cls" = 2 ]; then
    phoff="$(rd 32 8)"; phentsize="$(rd 54 2)"; phnum="$(rd 56 2)"
  else
    phoff="$(rd 28 4)"; phentsize="$(rd 42 2)"; phnum="$(rd 44 2)"
  fi
  for ((i = 0; i < phnum; i++)); do
    type="$(rd $((phoff + i * phentsize)) 4)"
    [ "$type" = 3 ] && return 0
  done
  return 1
}
# --------------------------------------------------------------------------

OUT=""
BUSYBOX=""
INIT=""
FILES=()
EXECS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --out)     OUT="$2";     shift 2 ;;
    --busybox) BUSYBOX="$2"; shift 2 ;;
    --init)    INIT="$2";    shift 2 ;;
    --file)    FILES+=("$2"); shift 2 ;;
    --exec)    EXECS+=("$2"); shift 2 ;;
    *) echo "mkinitramfs: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$OUT" ]     || { echo "mkinitramfs: --out required" >&2; exit 2; }
[ -n "$BUSYBOX" ] || { echo "mkinitramfs: --busybox required" >&2; exit 2; }
[ -n "$INIT" ]    || { echo "mkinitramfs: --init required" >&2; exit 2; }

if ! is_elf "$BUSYBOX" || elf_is_dynamic "$BUSYBOX"; then
  echo "mkinitramfs: busybox is not statically linked: $BUSYBOX" >&2
  exit 1
fi

WORK="$(mktemp -d -t mkinitramfs.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
ROOT="$WORK/rootfs"
mkdir -p "$ROOT"/{bin,sbin,etc,dev,proc,sys,tmp,run}

install -m 0755 "$BUSYBOX" "$ROOT/bin/busybox"
# Skip "busybox" itself — symlinking busybox→busybox creates ELOOP and
# breaks /init's shebang resolution at boot.
for applet in $("$BUSYBOX" --list); do
  [ "$applet" = "busybox" ] && continue
  ln -sf busybox "$ROOT/bin/$applet"
done
for sbin_applet in init mount umount sh; do
  ln -sf ../bin/busybox "$ROOT/sbin/$sbin_applet"
done

install -D -m 0755 "$INIT" "$ROOT/init"

for spec in "${FILES[@]:-}"; do
  [ -z "$spec" ] && continue
  src="${spec%%=*}"
  dst="${spec#*=}"
  case "$dst" in /*) ;; *) echo "mkinitramfs: dst must be absolute: $spec" >&2; exit 2 ;; esac
  install -D -m 0644 "$src" "$ROOT$dst"
done

for spec in "${EXECS[@]:-}"; do
  [ -z "$spec" ] && continue
  src="${spec%%=*}"
  dst="${spec#*=}"
  case "$dst" in /*) ;; *) echo "mkinitramfs: dst must be absolute: $spec" >&2; exit 2 ;; esac
  if is_elf "$src" && elf_is_dynamic "$src"; then
    echo "mkinitramfs: $src is dynamically linked; initramfs has no libc" >&2
    exit 1
  fi
  install -D -m 0755 "$src" "$ROOT$dst"
done

cat >"$ROOT/etc/fstab" <<'EOF'
proc      /proc       proc      defaults  0 0
sysfs     /sys        sysfs     defaults  0 0
devtmpfs  /dev        devtmpfs  defaults  0 0
tmpfs     /tmp        tmpfs     defaults  0 0
tmpfs     /run        tmpfs     defaults  0 0
EOF

# Pack with busybox's own cpio + gzip so no host cpio/gzip is needed. Paths
# are sorted for a stable archive order. `-R 0:0` records every entry as
# root-owned; otherwise the archive carries the build user's uid into the
# guest.
BB="$ROOT/bin/busybox"
# Fixed mtimes (the archive still records per-build inode numbers, so it is
# not bit-for-bit reproducible).
find "$ROOT" -exec touch -h -d @0 {} +
( cd "$ROOT" && find . | LC_ALL=C sort | "$BB" cpio -o -H newc -R 0:0 2>/dev/null \
  | "$BB" gzip -9 ) > "$OUT"
