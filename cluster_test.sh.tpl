#!/usr/bin/env bash
# firecracker_cluster_test wrapper (template). Boots N real microVMs of a
# firecracker_microvm runner on a shared host bridge via cluster_run.sh,
# then asserts a success marker appears in the designated node's serial log.
# Runs as a `local` (unsandboxed) test so it has the host network namespace
# + passwordless sudo for the bridge/TAP setup, and /dev/kvm.
set -uo pipefail

if [[ -z "${RUNFILES_DIR:-}" ]]; then
  if [[ -d "${BASH_SOURCE[0]}.runfiles" ]]; then RUNFILES_DIR="${BASH_SOURCE[0]}.runfiles"; fi
fi
if [[ -z "${RUNFILES_DIR:-}" && -n "${TEST_SRCDIR:-}" ]]; then RUNFILES_DIR="$TEST_SRCDIR"; fi
export RUNFILES_DIR
# shellcheck disable=SC1091
source "$RUNFILES_DIR/bazel_tools/tools/bash/runfiles/runfiles.bash" \
  || { echo "cluster-test: cannot source runfiles.bash" >&2; exit 1; }

RUNNER="$(rlocation '@@RUNNER_RLOC@@')"
CLUSTER_RUN="$(rlocation '@@CLUSTER_RUN_RLOC@@')"
[[ -x "$RUNNER" ]] || { echo "cluster-test: runner not found: @@RUNNER_RLOC@@" >&2; exit 1; }
[[ -f "$CLUSTER_RUN" ]] || { echo "cluster-test: cluster_run.sh not found" >&2; exit 1; }

if [[ ! -e /dev/kvm ]]; then echo "cluster-test: /dev/kvm absent — SKIP" >&2; exit 0; fi
if ! sudo -n true 2>/dev/null; then echo "cluster-test: passwordless sudo unavailable — SKIP" >&2; exit 0; fi

LOG="$(mktemp -d -t fc-cluster.XXXXXX)"
BRIDGE="ofdct$$"
# Node specs: a ';'-separated list of "IDX,IP,MAC,EXTRA" entries. Quoted so
# the ';' separators are literal data, then split on IFS.
NODES_RAW='@@NODES@@'
NODE_ARGS=()
OLD_IFS="$IFS"; IFS=';'
for spec in $NODES_RAW; do
  [[ -n "$spec" ]] && NODE_ARGS+=(--node "$spec")
done
IFS="$OLD_IFS"

bash "$CLUSTER_RUN" --runner "$RUNNER" --bridge "$BRIDGE" \
  --subnet-gw '@@SUBNET_GW@@' --timeout '@@TIMEOUT@@' --logdir "$LOG" \
  "${NODE_ARGS[@]}" >"$LOG/orch.log" 2>&1 || true

LEADER_LOG="$LOG/vm@@LEADER_IDX@@.log"
echo "=== leader (vm@@LEADER_IDX@@) tail ===" >&2
tail -n 25 "$LEADER_LOG" 2>/dev/null >&2 || true

if grep -qF '@@EXPECT_MARKER@@' "$LEADER_LOG" 2>/dev/null; then
  echo "cluster-test: PASS — found '@@EXPECT_MARKER@@'" >&2
  rm -rf "$LOG"
  exit 0
fi
echo "cluster-test: FAIL — '@@EXPECT_MARKER@@' not seen in $LEADER_LOG" >&2
exit 1
