#!/usr/bin/env bash
# Unit test for the firecracker_microvm launcher (runner.sh.tpl) without KVM:
# the microvms under test use `firecracker = ":fake_firecracker.sh"`, which
# dumps the vm.json it was given. Covers the `firecracker` override, every
# FC_* runtime knob, both boot modes, and that no host PATH lookup happens.
set -uo pipefail
source "${RUNFILES_DIR:-$TEST_SRCDIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
source "$(rlocation _main/tests/unit/testlib.sh)"

JQ="$(rlocation "$JQ_RLOC")"
INITRD_VM="$(rlocation _main/tests/unit/fake_initrd_vm)"
ROOTFS_VM="$(rlocation _main/tests/unit/fake_rootfs_vm)"
ROOTFS_EXTRA_VM="$(rlocation _main/tests/unit/fake_rootfs_extra_vm)"
D="$T/dump"; mkdir -p "$D"

boot() { # boot RUNNER [ENV=VAL...] — runs with an empty-ish PATH
  local r="$1"; shift
  rm -f "$D/vm.json"
  env "$@" FAKE_FC_DUMP="$D" PATH=/usr/bin:/bin "$r" >"$T/out" 2>&1
  rc=$?
}
j() { "$JQ" -r "$1" "$D/vm.json"; }

# --- initrd mode + extra_drive + custom machine config --------------------
boot "$INITRD_VM"
assert_rc 0 "$rc" "initrd launcher runs the fake firecracker"
assert_contains "$T/out" "FAKE_FIRECRACKER_ARGS=--no-api --config-file vm.json"
assert_contains "$T/out" "fc-runner: Firecracker vFAKE"
"$JQ" empty "$D/vm.json" && pass "vm.json is valid JSON" || fail "vm.json invalid"
[[ "$(j '."machine-config".vcpu_count')" == 3 ]] && pass "vcpus" || fail "vcpus=$(j '."machine-config".vcpu_count')"
[[ "$(j '."machine-config".mem_size_mib')" == 96 ]] && pass "mem_mib" || fail "mem"
[[ "$(j '."boot-source".initrd_path')" == initrd.cpio.gz ]] && pass "initrd_path" || fail "initrd_path"
[[ "$(j '."boot-source".boot_args')" == "console=ttyS0 custom.arg=1 "* ]] && pass "kernel_cmdline" || fail "boot_args=$(j '."boot-source".boot_args')"
[[ "$(j '.drives | length')" == 1 && "$(j '.drives[0].path_on_host')" == extra.img && "$(j '.drives[0].is_read_only')" == false ]] \
  && pass "extra_drive attached writable" || fail "drives=$(j .drives)"
[[ "$(j '."network-interfaces" // "none"')" == none ]] && pass "no NIC without FC_TAP" || fail "unexpected NIC"
assert_contains "$T/out" "RESOLVES:vmlinux.bin"
assert_contains "$T/out" "RESOLVES:initrd.cpio.gz"
assert_contains "$T/out" "RESOLVES:extra.img"

# --- networking + cmdline extra -------------------------------------------
boot "$INITRD_VM" FC_TAP=tapX FC_GUEST_MAC=06:00:00:00:00:99 FC_CMDLINE_EXTRA="ip=10.0.0.2::10.0.0.1:255.255.255.0::eth0:off"
[[ "$(j '."network-interfaces"[0].host_dev_name')" == tapX && "$(j '."network-interfaces"[0].guest_mac')" == 06:00:00:00:00:99 ]] \
  && pass "FC_TAP/FC_GUEST_MAC -> NIC" || fail "NIC=$(j '."network-interfaces"')"
[[ "$(j '."boot-source".boot_args')" == *"ip=10.0.0.2::10.0.0.1:255.255.255.0::eth0:off" ]] && pass "FC_CMDLINE_EXTRA appended" || fail "cmdline extra"

# --- rootfs mode + persistent disk ----------------------------------------
truncate -s 1M "$T/persist.img"
boot "$ROOTFS_VM" FC_PERSIST_DISK="$T/persist.img"
assert_rc 0 "$rc" "rootfs launcher"
[[ "$(j '."boot-source".boot_args')" == *"root=/dev/vda"* ]] && pass "root=/dev/vda" || fail "root arg"
[[ "$(j '.drives[0].is_root_device')" == true && "$(j '.drives[0].path_on_host')" == rootfs.ext4 ]] && pass "rootfs is root drive" || fail "root drive"
[[ "$(j '.drives[1].path_on_host')" == "$T/persist.img" ]] && pass "FC_PERSIST_DISK attached by absolute path" || fail "persist=$(j '.drives[1]')"
assert_contains "$T/out" "ROOTFS_WRITABLE_COPY"
[[ "$(j '."boot-source".initrd_path // "none"')" == none ]] && pass "no initrd in rootfs mode" || fail "initrd in rootfs mode"

# --- rootfs mode + extra_drive (+ persistent disk after it) ----------------
boot "$ROOTFS_EXTRA_VM" FC_PERSIST_DISK="$T/persist.img"
[[ "$(j '.drives | map(.path_on_host) | join(",")')" == "rootfs.ext4,extra.img,$T/persist.img" ]] \
  && pass "rootfs mode: root, extra_drive (/dev/vdb), then persist disk" || fail "drives=$(j '.drives')"

# --- FC_BOOT_DISK ----------------------------------------------------------
boot "$ROOTFS_VM" FC_BOOT_DISK="$T/persist.img"
[[ "$(j '."boot-source".boot_args')" == *"root=/dev/vda2"* && "$(j '.drives[0].path_on_host')" == "$T/persist.img" ]] \
  && pass "FC_BOOT_DISK boots the disk with root=/dev/vda2" || fail "boot disk: $(cat "$D/vm.json")"
boot "$ROOTFS_VM" FC_BOOT_DISK="$T/persist.img" FC_ROOT_PART=/dev/vda3
[[ "$(j '."boot-source".boot_args')" == *"root=/dev/vda3"* ]] && pass "FC_ROOT_PART" || fail "FC_ROOT_PART"
boot "$ROOTFS_VM" FC_BOOT_DISK="$T/nope.img"
assert_rc 1 "$rc" "missing FC_BOOT_DISK fails"

# --- FC_TIMEOUT kills a VM that never exits, and reports success ------------
s=$SECONDS
boot "$INITRD_VM" FC_TIMEOUT=2 FAKE_FC_SLEEP=60
assert_rc 0 "$rc" "FC_TIMEOUT kill exits 0"
[[ $((SECONDS - s)) -lt 15 ]] && pass "FC_TIMEOUT enforced" || fail "FC_TIMEOUT not enforced"
assert_contains "$T/out" "fc-runner: FC_TIMEOUT=2s reached, VM killed"
# ... but a real firecracker failure propagates.
boot "$INITRD_VM" FC_TIMEOUT=10 FAKE_FC_EXIT=3
assert_rc 3 "$rc" "firecracker exit code propagates under FC_TIMEOUT"
boot "$INITRD_VM" FAKE_FC_EXIT=4
assert_rc 4 "$rc" "firecracker exit code propagates"

# --- FC_FIRECRACKER runtime override ----------------------------------------
printf '#!/bin/sh\necho OVERRIDE_FC "$@"\n' >"$T/other_fc"; chmod +x "$T/other_fc"
boot "$INITRD_VM" FC_FIRECRACKER="$T/other_fc"
assert_contains "$T/out" "OVERRIDE_FC --no-api"
boot "$INITRD_VM" FC_FIRECRACKER="$T/does-not-exist"
assert_rc 1 "$rc" "nonexistent FC_FIRECRACKER fails"

# --- FC_KEEP_WORK keeps the work dir ----------------------------------------
boot "$INITRD_VM" FC_KEEP_WORK=1
kept="$(sed -n 's/^fc-runner: keeping work dir //p' "$T/out" | cut -d' ' -f1)"
[[ -n "$kept" && -f "$kept/extra.img" ]] && pass "FC_KEEP_WORK keeps extra.img" || fail "work dir not kept"
rm -rf "$kept"

# --- relative RUNFILES_DIR from another cwd (like `bazel run`) ---------------
rf_abs="${RUNFILES_DIR:-$TEST_SRCDIR}"
mkdir -p "$T/elsewhere" && cd "$T/elsewhere"
rel="$(realpath --relative-to="$T/elsewhere" "$rf_abs")"
rm -f "$D/vm.json"
env -u RUNFILES_MANIFEST_FILE RUNFILES_DIR="$rel" FAKE_FC_DUMP="$D" PATH=/usr/bin:/bin "$INITRD_VM" >"$T/out" 2>&1
assert_rc 0 $? "relative RUNFILES_DIR works"
assert_contains "$T/out" "RESOLVES:vmlinux.bin" "kernel symlink resolves with a relative RUNFILES_DIR"
cd /

finish
