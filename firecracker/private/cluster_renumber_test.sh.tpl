#!/usr/bin/env bash
# firecracker_renumber_test wrapper (template). Two-phase real multi-VM rig
# for CRITERIA §3/§4b: boot the cluster on subnet 1 (nodes form + persist
# identity + power off), then reboot the SAME nodes (same persistent disks)
# on subnet 2 — a LAN renumber — and assert the cluster HEALS (same mesh
# identity, new LAN IP) via a marker in a node's serial log. Runs as a
# `local` test (host net namespace + sudo for TAP/bridge + /dev/kvm); SKIPs
# cleanly when those are unavailable.
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
  if [[ "${FC_NO_SKIP:-}" == 1 ]]; then echo "renumber-test: $* — FAIL (FC_NO_SKIP=1)" >&2; exit 1; fi
  echo "renumber-test: $* — SKIP" >&2; exit 0
}

if [[ -z "${RUNFILES_DIR:-}" ]]; then
  if [[ -d "${BASH_SOURCE[0]}.runfiles" ]]; then RUNFILES_DIR="${BASH_SOURCE[0]}.runfiles"; fi
fi
if [[ -z "${RUNFILES_DIR:-}" && -n "${TEST_SRCDIR:-}" ]]; then RUNFILES_DIR="$TEST_SRCDIR"; fi
export RUNFILES_DIR
# shellcheck disable=SC1091
source "$RUNFILES_DIR/bazel_tools/tools/bash/runfiles/runfiles.bash" \
  || { echo "renumber-test: cannot source runfiles.bash" >&2; exit 1; }

RUNNER="$(rlocation '@@RUNNER_RLOC@@')"
CLUSTER_RUN="$(rlocation '@@CLUSTER_RUN_RLOC@@')"
[[ -x "$RUNNER" ]] || { echo "renumber-test: runner not found" >&2; exit 1; }
if [[ ! -w /dev/kvm ]]; then skip "/dev/kvm absent or not writable"; fi
if ! sudo -n true 2>/dev/null; then skip "passwordless sudo unavailable"; fi

LOG="$(mktemp -d -t fc-renumber.XXXXXX)"
PERSIST="$LOG/persist"
BRIDGE="ofdrn$$"

run_phase() { # $1=phase $2=gw $3=nodes-semicolon-list $4=timeout
  local phase="$1" gw="$2" nodes_raw="$3" tmo="$4"
  local args=() ; local OLD_IFS="$IFS"; IFS=';'
  for spec in $nodes_raw; do [[ -n "$spec" ]] && args+=(--node "$spec"); done
  IFS="$OLD_IFS"
  bash "$CLUSTER_RUN" --runner "$RUNNER" --bridge "$BRIDGE" --subnet-gw "$gw" \
    --timeout "$tmo" --logdir "$LOG/p${phase}" --persist-dir "$PERSIST" \
    "${args[@]}" >"$LOG/p${phase}.orch" 2>&1 || true
}

echo "renumber-test: PHASE 1 (form + persist)" >&2
run_phase 1 '@@GW1@@' '@@NODES1@@' '@@TIMEOUT1@@'
echo "renumber-test: PHASE 2 (renumber + heal)" >&2
run_phase 2 '@@GW2@@' '@@NODES2@@' '@@TIMEOUT2@@'

echo "=== phase-2 markers ===" >&2
grep -hE 'OFD_PHASE:|OFD_HEAL|OFD_CLUSTER' "$LOG"/p2/vm*.log 2>/dev/null >&2 || true

if grep -qhF '@@EXPECT_MARKER@@' "$LOG"/p2/vm*.log 2>/dev/null; then
  echo "renumber-test: PASS — found '@@EXPECT_MARKER@@'" >&2
  rm -rf "$LOG"; exit 0
fi
dump_logs "$LOG"
echo "renumber-test: FAIL — '@@EXPECT_MARKER@@' not seen after renumber" >&2
exit 1
