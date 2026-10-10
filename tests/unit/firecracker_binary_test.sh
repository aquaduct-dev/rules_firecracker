#!/usr/bin/env bash
# //firecracker:firecracker is the pinned upstream release, statically
# linked, and runnable without anything from the host PATH.
set -uo pipefail
source "${RUNFILES_DIR:-$TEST_SRCDIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
source "$(rlocation _main/tests/unit/testlib.sh)"

FC="$(rlocation "$FIRECRACKER_RLOC")"
[[ -x "$FC" ]] && pass "firecracker is executable" || fail "firecracker not executable: $FC"
is_elf "$FC" && ! elf_is_dynamic "$FC" && pass "firecracker is a static ELF" || fail "firecracker is not static"
out="$(env -i "$FC" --version 2>&1)"
echo "$out" | grep -qx 'Firecracker v1.17.0' && pass "version is v1.17.0" || fail "unexpected version: $out"
finish
