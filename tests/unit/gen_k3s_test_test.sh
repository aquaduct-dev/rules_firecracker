#!/usr/bin/env bash
# Unit test for //firecracker:gen_k3s_test, the firecracker_k3s_test
# launcher generator: report extraction between ===REPORT_BEGIN/END===,
# pass_conditions evaluation with the hermetic jq, and failure modes.
set -uo pipefail
source "${RUNFILES_DIR:-$TEST_SRCDIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
source "$(rlocation _main/tests/unit/testlib.sh)"

GEN="$(rlocation _main/firecracker/gen_k3s_test)"
JQ="$(rlocation "$JQ_RLOC")"
RF_LIB="$(rlocation bazel_tools/tools/bash/runfiles/runfiles.bash)"

RF="$T/rf"
mkdir -p "$RF/bazel_tools/tools/bash/runfiles" "$RF/fake"
cp "$RF_LIB" "$RF/bazel_tools/tools/bash/runfiles/runfiles.bash"
ln -s "$JQ" "$RF/fake/jq"
"$GEN" --out "$T/t.sh" --runner-rloc fake/runner --jq-rloc fake/jq --timeout 30

report_runner() { # report_runner JSON_LINES...
  {
    echo '#!/usr/bin/env bash'
    echo 'echo "[k3s-init] booting"; echo K3S_READY; echo SCENARIO_BEGIN:s'
    echo 'echo "===REPORT_BEGIN==="'
    echo 'echo "[    1.234] stray kernel line"'
    for l in "$@"; do printf 'printf "%%s\\n" %q\n' "$l"; done
    echo 'echo "===REPORT_END==="; echo SCENARIO_END:s:0; echo K3S_POWEROFF'
  } >"$RF/fake/runner"
  chmod +x "$RF/fake/runner"
}
run() {
  OUTD="$T/outputs.$RANDOM"; mkdir -p "$OUTD"
  # Minimal PATH, as under bazel; jq comes from runfiles.
  env -u RUNFILES_MANIFEST_FILE -u RUNFILES_MANIFEST_ONLY RUNFILES_DIR="$RF" \
    TEST_UNDECLARED_OUTPUTS_DIR="$OUTD" SCENARIO_REPORT_PATH="$T/mirror/report.json" \
    PATH=/usr/bin:/bin "$T/t.sh" >"$T/out" 2>&1
  rc=$?
}

# 1. All pass_conditions passed -> 0; report persisted + mirrored.
report_runner '{"scenario":"s","pass_conditions":[' '{"id":"a","label":"a","passed":true},' '{"id":"b","label":"b","passed":true}]}'
run; assert_rc 0 "$rc" "all pass_conditions passed -> pass"
[[ "$("$JQ" -r '.pass_conditions | length' "$OUTD/report.json")" == 2 ]] && pass "report.json in undeclared outputs" || fail "report.json missing"
[[ -s "$OUTD/serial.log" ]] && pass "serial.log saved" || fail "serial.log missing"
[[ -s "$T/mirror/report.json" ]] && pass "mirrored to SCENARIO_REPORT_PATH" || fail "SCENARIO_REPORT_PATH not written"

# 2. One failing PC -> 1, PC listed.
report_runner '{"scenario":"s","pass_conditions":[{"id":"a","label":"a","passed":true},{"id":"bad.pc","label":"bad","passed":false,"error":"boom"}]}'
run; assert_rc 1 "$rc" "a failing pass_condition fails"
assert_contains "$T/out" "bad.pc"
assert_contains "$T/out" "boom"

# 3. Empty pass_conditions -> 1.
report_runner '{"scenario":"s","pass_conditions":[]}'
run; assert_rc 1 "$rc" "empty pass_conditions fails"
assert_contains "$T/out" "no pass_conditions"

# 4. passed must be literally true.
report_runner '{"pass_conditions":[{"id":"x","label":"x","passed":"true"}]}'
run; assert_rc 1 "$rc" "passed:\"true\" (string) fails"

# 5. Garbage between the markers -> 1.
report_runner '{ this is not json'
run; assert_rc 1 "$rc" "unparseable report fails"

# 6. No markers at all -> 1.
printf '#!/usr/bin/env bash\necho K3S_FAILED\n' >"$RF/fake/runner"
run; assert_rc 1 "$rc" "missing report fails"
assert_contains "$T/out" "no report JSON found"

finish
