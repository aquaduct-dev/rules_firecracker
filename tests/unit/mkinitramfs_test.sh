#!/usr/bin/env bash
# Unit test for //firecracker:mkinitramfs (the firecracker_initramfs tool)
# and for the output of a real firecracker_initramfs target.
set -uo pipefail
source "${RUNFILES_DIR:-$TEST_SRCDIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
source "$(rlocation _main/tests/unit/testlib.sh)"

MK="$(rlocation _main/firecracker/mkinitramfs)"
BB="$(rlocation "$BUSYBOX_RLOC")"
MACRO_OUT="$(rlocation "$MACRO_INITRD_RLOC")"

unpack() { # unpack ARCHIVE DIR
  mkdir -p "$2" && "$BB" gzip -dc "$1" | (cd "$2" && "$BB" cpio -i -d 2>/dev/null)
}

echo "init" >"$T/init.sh"; chmod +x "$T/init.sh"
echo "data" >"$T/data.txt"
mkelf "$T/static.elf" 1
mkelf "$T/dynamic.elf" 6 3 1
printf '#!/bin/sh\necho script\n' >"$T/script.sh"

# 1. Happy path: layout, modes, applet symlinks, static ELF + script accepted.
"$MK" --out "$T/ok.cpio.gz" --busybox "$BB" --init "$T/init.sh" \
  --file "$T/data.txt=/etc/data.txt" --exec "$T/static.elf=/opt/static" \
  --exec "$T/script.sh=/usr/bin/script" 2>"$T/err"
assert_rc 0 $? "packs an initramfs with files + static execs"
"$BB" gzip -dc "$T/ok.cpio.gz" | "$BB" cpio -t -v 2>/dev/null >"$T/list"
"$BB" gzip -dc "$T/ok.cpio.gz" | "$BB" cpio -t 2>/dev/null | sed 's|^\./||' >"$T/names"
for p in init bin/busybox bin/sh sbin/init etc/data.txt etc/fstab opt/static usr/bin/script dev proc sys tmp run; do
  grep -qx "$p" "$T/names" && pass "archive has /$p" || fail "archive missing /$p"
done
grep -E ' init$' "$T/list" | grep -q '^-rwxr-xr-x' && pass "/init is 0755" || fail "/init mode: $(grep -E ' init$' "$T/list")"
grep -E ' etc/data.txt$' "$T/list" | grep -q '^-rw-r--r--' && pass "--file is 0644" || fail "--file mode wrong"
grep -E ' opt/static$' "$T/list" | grep -q '^-rwxr-xr-x' && pass "--exec is 0755" || fail "--exec mode wrong"
grep -E ' bin/sh -> busybox$' "$T/list" >/dev/null && pass "/bin/sh -> busybox" || fail "/bin/sh is not a busybox symlink"
grep -qx 'bin/busybox' "$T/names" && ! grep -E ' bin/busybox -> ' "$T/list" >/dev/null \
  && pass "no busybox->busybox self-link" || fail "busybox self-link present"
unpack "$T/ok.cpio.gz" "$T/x"
[[ "$(cat "$T/x/etc/data.txt")" == data ]] && pass "file content preserved" || fail "file content changed"

# 2. Dynamic ELF in --exec is rejected (initramfs has no libc).
"$MK" --out "$T/dyn.cpio.gz" --busybox "$BB" --init "$T/init.sh" \
  --exec "$T/dynamic.elf=/opt/dyn" 2>"$T/err"
assert_rc nonzero $? "rejects a dynamically-linked --exec"
assert_contains "$T/err" "dynamically linked"

# 2b. A real dynamic binary from the host, when there is one.
host_ls="$(command -v ls || true)"
if [[ -n "$host_ls" ]] && od -An -c -N4 "$host_ls" | tr -d ' ' | grep -qx '177ELF'; then
  "$MK" --out "$T/dyn2.cpio.gz" --busybox "$BB" --init "$T/init.sh" --exec "$host_ls=/bin/hostls" 2>"$T/err"
  assert_rc nonzero $? "rejects the host's dynamic $host_ls"
fi

# 3. A dynamic "busybox" is rejected.
"$MK" --out "$T/bb.cpio.gz" --busybox "$T/dynamic.elf" --init "$T/init.sh" 2>"$T/err"
assert_rc nonzero $? "rejects a non-static busybox"
assert_contains "$T/err" "not statically linked"

# 4. Relative destinations and unknown flags are usage errors.
"$MK" --out "$T/rel.cpio.gz" --busybox "$BB" --init "$T/init.sh" --file "$T/data.txt=etc/x" 2>"$T/err"
assert_rc 2 $? "relative --file dst is rejected"
"$MK" --out "$T/u.cpio.gz" --busybox "$BB" --init "$T/init.sh" --bogus 2>"$T/err"
assert_rc 2 $? "unknown flag is rejected"
"$MK" --busybox "$BB" --init "$T/init.sh" 2>"$T/err"
assert_rc 2 $? "missing --out is rejected"

# 5. The firecracker_initramfs macro output (tests/vm:initrd).
unpack "$MACRO_OUT" "$T/m"
[[ -x "$T/m/init" ]] && pass "macro: /init executable" || fail "macro: /init missing"
[[ "$(cat "$T/m/etc/greeting")" == "hello from files" ]] && pass "macro: files mapped" || fail "macro: /etc/greeting wrong"
[[ -x "$T/m/opt/bin/busybox" ]] && pass "macro: execs mapped" || fail "macro: /opt/bin/busybox missing"

finish
