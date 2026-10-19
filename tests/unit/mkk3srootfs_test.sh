#!/usr/bin/env bash
# Unit test for //firecracker:mkk3srootfs (the firecracker_k3s_test rootfs
# builder). Uses busybox as a stand-in static "k3s" and test binary.
set -uo pipefail
source "${RUNFILES_DIR:-$TEST_SRCDIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
source "$(rlocation _main/tests/unit/testlib.sh)"

MK="$(rlocation _main/firecracker/mkk3srootfs)"
BB="$(rlocation "$BUSYBOX_RLOC")"
INIT="$(rlocation "$K3S_INIT_RLOC")"

echo "kind: ConfigMap" >"$T/m.yaml"
echo "not-really-a-tar" >"$T/img.tar"
echo "f" >"$T/f.txt"
mkelf "$T/dynamic.elf" 3

common=(--busybox "$BB" --k3s "$BB" --init "$INIT" --scenario myscenario --size-mb 64 --label k3s)
"$MK" --out "$T/k.ext4" "${common[@]}" --test-binary "$BB" --test-binary-name mytest \
  --manifest "$T/m.yaml=fixture.yaml" --image "$T/img.tar=img.tar" \
  --file "$T/f.txt=/etc/extra/f.txt" --exec "$BB=/usr/local/bin/extra-tool" 2>"$T/err"
assert_rc 0 $? "builds a k3s rootfs"
I="$T/k.ext4"
for p in /usr/local/bin/k3s /usr/local/bin/mytest /usr/local/bin/extra-tool /sbin/init /bin/busybox \
         /etc/manifests/fixture.yaml /etc/images/img.tar /etc/extra/f.txt /etc/passwd /etc/hosts /etc/resolv.conf; do
  debugfs_exists "$I" "$p" && pass "has $p" || fail "missing $p"
done
debugfs -R "stat /usr/local/bin/kubectl" "$I" 2>/dev/null | grep -q 'Fast link dest: "k3s"' \
  && pass "kubectl -> k3s" || fail "kubectl symlink missing"
[[ "$(debugfs_cat "$I" /etc/scenario)" == myscenario ]] && pass "/etc/scenario" || fail "/etc/scenario"
[[ "$(debugfs_cat "$I" /etc/test_binary)" == mytest ]] && pass "/etc/test_binary" || fail "/etc/test_binary"
[[ "$(debugfs_mode "$I" /usr/local/bin/mytest)" == 0755 ]] && pass "test binary 0755" || fail "test binary mode"
[[ "$(debugfs_mode "$I" /etc/extra/f.txt)" == 0644 ]] && pass "--file 0644" || fail "--file mode"
for p in / /etc/extra/f.txt /usr/local/bin/mytest /sbin/init; do
  o="$(debugfs_owner "$I" "$p")"
  [[ "$o" == 0:0 ]] && pass "$p owned 0:0" || fail "$p owned $o, want 0:0"
done
cmp -s <(debugfs_cat "$I" /sbin/init) "$INIT" && pass "/sbin/init is the init script" || fail "/sbin/init differs"

"$MK" --out "$T/d.ext4" "${common[@]}" --test-binary "$T/dynamic.elf" --test-binary-name t 2>"$T/err"
assert_rc nonzero $? "rejects a dynamic test binary"
assert_contains "$T/err" "dynamically linked"
"$MK" --out "$T/d2.ext4" --busybox "$BB" --k3s "$T/dynamic.elf" --init "$INIT" --scenario s \
  --size-mb 64 --label k3s --test-binary "$BB" --test-binary-name t 2>"$T/err"
assert_rc nonzero $? "rejects a dynamic k3s"
"$MK" --out "$T/d3.ext4" "${common[@]}" --test-binary "$BB" --test-binary-name t --manifest "$T/m.yaml=sub/x.yaml" 2>"$T/err"
assert_rc 2 $? "manifest dst must be a basename"
"$MK" --out "$T/d4.ext4" "${common[@]}" 2>"$T/err"
assert_rc 2 $? "missing --test-binary rejected"

finish
