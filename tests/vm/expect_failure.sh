#!/usr/bin/env bash
# Runs another (manual) test target's script and asserts that it FAILS:
# non-zero exit, a given diagnostic in its output, and (optionally) that it
# failed within a time bound.
#
# Env: INNER_RLOC (rlocation path of the inner test), WANT (substring its
# output must contain), MAX_SECONDS (optional time bound).
set -uo pipefail

# shellcheck disable=SC1090
source "${RUNFILES_DIR:-$TEST_SRCDIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"

inner="$(rlocation "$INNER_RLOC")"
want="$WANT"
max="${MAX_SECONDS:-}"
[[ -x "$inner" ]] || { echo "expect_failure: inner test $INNER_RLOC not found" >&2; exit 1; }

out="$(mktemp)"
start=$SECONDS
"$inner" >"$out" 2>&1
rc=$?
elapsed=$((SECONDS - start))
cat "$out"
echo "expect_failure: inner exit=$rc after ${elapsed}s" >&2

if [[ $rc -eq 0 ]]; then
  echo "expect_failure: FAIL — inner test passed but should have failed" >&2
  exit 1
fi
if ! grep -qF -- "$want" "$out"; then
  echo "expect_failure: FAIL — expected diagnostic not found: $want" >&2
  exit 1
fi
if [[ -n "$max" && $elapsed -gt $max ]]; then
  echo "expect_failure: FAIL — took ${elapsed}s, limit ${max}s" >&2
  exit 1
fi
echo "expect_failure: PASS (inner failed as expected)" >&2
