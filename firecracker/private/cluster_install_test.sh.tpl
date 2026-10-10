#!/usr/bin/env bash
# firecracker_install_cluster_test wrapper (template). Real §28 rig: for each
# node, run the REAL openfactoryd-installer to lay a bootable cluster rootfs
# onto a fresh GPT disk (install-to-disk), then boot every node from its
# installed disk (no installer media) on a shared bridge and assert the
# cluster forms. Runs `local` (host netns + sudo for losetup/TAP + kvm);
# SKIPs cleanly when unavailable.
set -uo pipefail
# Host tools (ip, mkfs.ext4, losetup, ...) live in sbin dirs that bazel's
# default test PATH omits.
export PATH="/usr/local/sbin:/usr/sbin:/sbin:${PATH:-/usr/bin:/bin}"
# A missing prerequisite SKIPs (exit 0) unless FC_NO_SKIP=1, which turns it
# into a failure (CI sets it so a broken runner can't pass silently).
dump_logs() { # print the tail of every log under $1 (CI diagnostics)
  local f
  for f in $(find "$1" -name '*.log' -o -name '*.orch' | sort); do
    echo "=== ${f#$1/} (tail) ===" >&2
    grep -v 'IO \(read\|write\) @' "$f" | tail -n 40 >&2
  done
}
skip() {
  if [[ "${FC_NO_SKIP:-}" == 1 ]]; then echo "install-test: $* — FAIL (FC_NO_SKIP=1)" >&2; exit 1; fi
  echo "install-test: $* — SKIP" >&2; exit 0
}

if [[ -z "${RUNFILES_DIR:-}" ]]; then
  if [[ -d "${BASH_SOURCE[0]}.runfiles" ]]; then RUNFILES_DIR="${BASH_SOURCE[0]}.runfiles"; fi
fi
if [[ -z "${RUNFILES_DIR:-}" && -n "${TEST_SRCDIR:-}" ]]; then RUNFILES_DIR="$TEST_SRCDIR"; fi
export RUNFILES_DIR
# shellcheck disable=SC1091
source "$RUNFILES_DIR/bazel_tools/tools/bash/runfiles/runfiles.bash" \
  || { echo "install-test: cannot source runfiles.bash" >&2; exit 1; }

RUNNER="$(rlocation '@@RUNNER_RLOC@@')"
CLUSTER_RUN="$(rlocation '@@CLUSTER_RUN_RLOC@@')"
# go_binary and other executables lay the binary out differently; take the
# first candidate rlocation path that resolves to an executable.
INSTALLER=""
for cand in @@INSTALLER_RLOCS@@; do
  p="$(rlocation "$cand" 2>/dev/null || true)"
  if [[ -n "$p" && -f "$p" && -x "$p" ]]; then INSTALLER="$p"; break; fi
done
ROOTFS="$(rlocation '@@ROOTFS_RLOC@@')"
[[ -x "$RUNNER" && -x "$INSTALLER" && -f "$ROOTFS" ]] || { echo "install-test: missing runner/installer/rootfs" >&2; exit 1; }
if [[ ! -w /dev/kvm ]]; then skip "/dev/kvm absent or not writable"; fi
if ! sudo -n true 2>/dev/null; then skip "passwordless sudo unavailable"; fi
for t in losetup sgdisk mkfs.fat mkfs.ext4 mkfs.exfat; do command -v "$t" >/dev/null || skip "missing host tool $t"; done

LOG="$(mktemp -d -t fc-install.XXXXXX)"
INST="$LOG/installed"; mkdir -p "$INST"
SECRET='@@SECRET@@'

echo "install-test: PHASE 1 — install each node to disk" >&2
for idx in @@IDXS@@; do
  DISK="$INST/installed-${idx}.img"
  truncate -s 5G "$DISK"
  LOOP="$(sudo -n losetup -fP --show "$DISK")"
  cat > "$LOG/settings-${idx}.ini" <<EOF
[node]
role = server
[cluster]
cluster_secret = ${SECRET}
[install]
target_disk = ${LOOP}
wipe_confirm = yes-i-am-sure
EOF
  sudo -n "$INSTALLER" --settings "$LOG/settings-${idx}.ini" --rootfs-image "$ROOTFS" >"$LOG/install-${idx}.log" 2>&1 \
    || { echo "install-test: installer failed for node $idx" >&2; sudo -n losetup -d "$LOOP" 2>/dev/null; tail -5 "$LOG/install-${idx}.log" >&2; }
  sudo -n losetup -d "$LOOP" 2>/dev/null
done

echo "install-test: PHASE 2 — boot each node from its installed disk" >&2
NODES_RAW='@@NODES@@'
NODE_ARGS=(); OLD_IFS="$IFS"; IFS=';'
for spec in $NODES_RAW; do [[ -n "$spec" ]] && NODE_ARGS+=(--node "$spec"); done
IFS="$OLD_IFS"
bash "$CLUSTER_RUN" --runner "$RUNNER" --bridge "ofdinst$$" --subnet-gw '@@GW@@' \
  --timeout '@@TIMEOUT@@' --logdir "$LOG/boot" --boot-disk-dir "$INST" \
  "${NODE_ARGS[@]}" >"$LOG/orch.log" 2>&1 || true

echo "=== node markers ===" >&2
grep -hE 'OFD_BOOTING|OFD_CLUSTER|Mounted root|Cannot open root' "$LOG"/boot/vm*.log 2>/dev/null | tail -20 >&2 || true
if grep -qhF '@@EXPECT_MARKER@@' "$LOG"/boot/vm*.log 2>/dev/null; then
  echo "install-test: PASS — found '@@EXPECT_MARKER@@'" >&2
  rm -rf "$LOG"; exit 0
fi
dump_logs "$LOG"
echo "install-test: FAIL — '@@EXPECT_MARKER@@' not seen" >&2
exit 1
