#!/usr/bin/env bash
set -euo pipefail
source "${RUNFILES_DIR:-$TEST_SRCDIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
fc="$(rlocation "$FC_RLOC")"
"$fc" --version | grep -q '^Firecracker v' && echo "ok: $("$fc" --version | head -n1)"
