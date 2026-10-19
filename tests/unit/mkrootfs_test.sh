#!/usr/bin/env bash
# Unit test for //firecracker:mkrootfs (firecracker_rootfs) and the output
# of a real firecracker_rootfs target. Inspects images with debugfs.
set -uo pipefail
source "${RUNFILES_DIR:-$TEST_SRCDIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
source "$(rlocation _main/tests/unit/testlib.sh)"

MK="$(rlocation _main/firecracker/mkrootfs)"
MACRO_OUT="$(rlocation "$MACRO_ROOTFS_RLOC")"
command -v debugfs >/dev/null || { echo "debugfs (e2fsprogs) required" >&2; exit 1; }

echo "hello" >"$T/a.txt"
printf '#!/bin/sh\n' >"$T/run.sh"

"$MK" --out "$T/img.ext4" --size-mb 8 --label unitlabel \
  --file "$T/a.txt=/etc/a.txt" --exec "$T/run.sh=/usr/bin/run" 2>"$T/err"
assert_rc 0 $? "builds an ext4 image"
[[ "$(stat -c %s "$T/img.ext4")" -eq $((8 * 1024 * 1024)) ]] && pass "image is size_mb" || fail "image size $(stat -c %s "$T/img.ext4")"
debugfs -R stats "$T/img.ext4" 2>/dev/null | grep -q 'Filesystem volume name: *unitlabel' && pass "label set" || fail "label not set"
[[ "$(debugfs_cat "$T/img.ext4" /etc/a.txt)" == hello ]] && pass "file content" || fail "file content wrong"
[[ "$(debugfs_mode "$T/img.ext4" /etc/a.txt)" == 0644 ]] && pass "--file 0644" || fail "--file mode $(debugfs_mode "$T/img.ext4" /etc/a.txt)"
[[ "$(debugfs_mode "$T/img.ext4" /usr/bin/run)" == 0755 ]] && pass "--exec 0755" || fail "--exec mode $(debugfs_mode "$T/img.ext4" /usr/bin/run)"
# Staged by the (non-root) build user, but root-owned in the guest.
for p in / /etc /etc/a.txt /usr/bin/run; do
  o="$(debugfs_owner "$T/img.ext4" "$p")"
  [[ "$o" == 0:0 ]] && pass "$p owned 0:0" || fail "$p owned $o, want 0:0"
done
e2fsck -fn "$T/img.ext4" >/dev/null 2>&1 && pass "fsck clean" || fail "fsck reports errors"

"$MK" --out "$T/bad.ext4" --size-mb 8 --label x --file "$T/a.txt=relative" 2>"$T/err"
assert_rc 2 $? "relative dst rejected"
"$MK" --out "$T/bad.ext4" --label x 2>"$T/err"
assert_rc 2 $? "missing --size-mb rejected"
# Too small for its contents: mkfs.ext4 -d must fail loudly.
# Random bytes: mkfs.ext4 -d would store zeros sparsely.
head -c $((3 * 1024 * 1024)) /dev/urandom >"$T/big.bin"
"$MK" --out "$T/small.ext4" --size-mb 1 --label x --file "$T/big.bin=/big" 2>"$T/err"
assert_rc nonzero $? "image smaller than its contents fails"

# Macro output: tests/vm:rootfs.
debugfs -R stats "$MACRO_OUT" 2>/dev/null | grep -q 'Filesystem volume name: *fctestroot' && pass "macro: label" || fail "macro: label"
[[ "$(debugfs_mode "$MACRO_OUT" /sbin/init)" == 0755 ]] && pass "macro: /sbin/init 0755" || fail "macro: /sbin/init"
debugfs_exists "$MACRO_OUT" /bin/busybox && pass "macro: /bin/busybox" || fail "macro: /bin/busybox missing"
[[ "$(debugfs_cat "$MACRO_OUT" /etc/rootfs-greeting)" == "hello from the ext4 rootfs" ]] && pass "macro: files" || fail "macro: files"

finish
