#!/usr/bin/env bash
# Unit test for //firecracker:gen_test, the firecracker_test script
# generator. Drives generated scripts against fake microvm runners (no KVM):
# marker pass/fail, early exit, hard deadline, and quoting.
set -uo pipefail
source "${RUNFILES_DIR:-$TEST_SRCDIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
source "$(rlocation _main/tests/unit/testlib.sh)"

GEN="$(rlocation _main/firecracker/gen_test)"
RF_LIB="$(rlocation bazel_tools/tools/bash/runfiles/runfiles.bash)"

# A private runfiles tree holding runfiles.bash and the fake runner.
RF="$T/rf"
mkdir -p "$RF/bazel_tools/tools/bash/runfiles" "$RF/fake"
cp "$RF_LIB" "$RF/bazel_tools/tools/bash/runfiles/runfiles.bash"

fake_runner() { # fake_runner BODY — install the fake microvm launcher
  printf '#!/usr/bin/env bash\n%s\n' "$1" >"$RF/fake/runner"; chmod +x "$RF/fake/runner"
}
gen() { "$GEN" --out "$T/t.sh" --runner-rloc fake/runner "$@"; }
run() { # run -> rc in $rc, output in $T/out, seconds in $secs
  local s=$SECONDS
  env -u RUNFILES_MANIFEST_FILE -u RUNFILES_MANIFEST_ONLY RUNFILES_DIR="$RF" "$T/t.sh" >"$T/out" 2>&1
  rc=$?; secs=$((SECONDS - s))
}

# 1. All markers present, VM exits by itself -> pass.
fake_runner 'echo "boot"; echo "MARK_A"; echo "MARK B with spaces"'
gen --timeout 20 --expect MARK_A --expect "MARK B with spaces" --unexpect PANIC
run; assert_rc 0 "$rc" "all expect markers seen -> pass"
assert_contains "$T/out" "PASS expect: MARK_A"
assert_contains "$T/out" "PASS unexpect: PANIC (absent)"

# 2. Early exit: markers appear, runner would otherwise hang for 120s.
fake_runner 'echo "MARK_A"; sleep 120'
gen --timeout 120 --expect MARK_A
run; assert_rc 0 "$rc" "early exit passes"
[[ $secs -lt 20 ]] && pass "early exit killed the VM quickly (${secs}s)" || fail "early exit took ${secs}s"
assert_contains "$T/out" "killing microvm early"

# 3. Missing expect marker -> fail.
fake_runner 'echo "MARK_A"'
gen --timeout 20 --expect MARK_A --expect MISSING
run; assert_rc 1 "$rc" "missing expect marker fails"
assert_contains "$T/out" "FAIL expect: MISSING (not found)"

# 4. Unexpected marker present -> fail.
fake_runner 'echo "MARK_A"; echo "Kernel panic - not syncing"'
gen --timeout 20 --unexpect "Kernel panic"
run; assert_rc 1 "$rc" "unexpected marker fails"
assert_contains "$T/out" "FAIL unexpect: Kernel panic (found)"

# 5. Runner ignores FC_TIMEOUT and never exits: the hard deadline
#    (timeout + 5s) kills it and the missing marker fails the test.
fake_runner 'echo "hung"; sleep 300'
gen --timeout 2 --expect NEVER
run; assert_rc 1 "$rc" "hung runner + missing marker fails"
[[ $secs -lt 20 ]] && pass "hard deadline enforced (${secs}s)" || fail "hard deadline took ${secs}s"
assert_contains "$T/out" "hard deadline hit"

# 6. FC_TIMEOUT is exported to the runner.
fake_runner 'echo "FC_TIMEOUT_IS=$FC_TIMEOUT"'
gen --timeout 7 --expect FC_TIMEOUT_IS=7
run; assert_rc 0 "$rc" "runner receives FC_TIMEOUT"

# 7. Shell-hostile markers are matched literally (fixed string, no glob/regex).
fake_runner $'echo \'quote\'"\'"\'s $HOME [a-z]* "dq"\''
gen --timeout 20 --expect "quote's \$HOME [a-z]* \"dq\"" --unexpect '.*'
run; assert_rc 0 "$rc" "special characters matched literally"

# 8. No markers at all: passes once the VM exits.
fake_runner 'echo hi'
gen --timeout 20
run; assert_rc 0 "$rc" "no markers -> pass after exit"

# 9. Missing runner -> fail.
rm -f "$RF/fake/runner"
gen --timeout 5 --expect X
run; assert_rc 1 "$rc" "missing runner fails"

# 10. Generator usage errors.
"$GEN" --out "$T/x.sh" --timeout 5 2>/dev/null; assert_rc 2 $? "missing --runner-rloc rejected"
"$GEN" --out "$T/x.sh" --runner-rloc a --timeout 5 --nope 2>/dev/null; assert_rc 2 $? "unknown flag rejected"

finish
