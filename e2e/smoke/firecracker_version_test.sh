#!/usr/bin/env bash
set -euo pipefail
source "${RUNFILES_DIR:-$TEST_SRCDIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
fc="$(rlocation "$FC_RLOC")"
# Run it once; keep the first line (no pipe to head, which pipefail could trip).
version="$("$fc" --version)"
version="${version%%$'\n'*}"
[[ "$version" == "Firecracker v"* ]] || { echo "unexpected firecracker --version: $version" >&2; exit 1; }
echo "ok: $version"
