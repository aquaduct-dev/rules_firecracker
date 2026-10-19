# Shared helpers for the unit tests. Source after runfiles.bash.
# shellcheck shell=bash

# e2fsprogs (debugfs, mkfs.ext4) lives in sbin dirs bazel's test PATH omits.
export PATH="/usr/local/sbin:/usr/sbin:/sbin:${PATH:-/usr/bin:/bin}"

T="$(mktemp -d "${TEST_TMPDIR:-/tmp}/fcunit.XXXXXX")"
FAILS=0

fail() { echo "FAIL: $*" >&2; FAILS=$((FAILS + 1)); }
pass() { echo "ok: $*" >&2; }
finish() {
  if [[ $FAILS -gt 0 ]]; then echo "$FAILS check(s) failed" >&2; exit 1; fi
  echo "all checks passed" >&2
}

# assert_contains FILE SUBSTRING [description]
assert_contains() {
  if grep -qF -- "$2" "$1"; then pass "${3:-$1 contains '$2'}"; else fail "${3:-$1 should contain '$2'}"; echo "--- $1:" >&2; cat "$1" >&2; fi
}
assert_not_contains() {
  if grep -qF -- "$2" "$1"; then fail "${3:-$1 should not contain '$2'}"; else pass "${3:-$1 lacks '$2'}"; fi
}
# assert_rc EXPECTED ACTUAL description
assert_rc() {
  if [[ "$1" == nonzero ]]; then
    if [[ "$2" -ne 0 ]]; then pass "$3 (rc=$2)"; else fail "$3: expected non-zero rc"; fi
  elif [[ "$1" -eq "$2" ]]; then pass "$3"; else fail "$3: expected rc=$1, got $2"; fi
}

# mkelf OUT PT_TYPE... — write a minimal little-endian ELF64 executable
# header whose program headers have the given p_type values (3 = PT_INTERP,
# i.e. "dynamically linked"; 1 = PT_LOAD). Enough for the PT_INTERP check.
mkelf() {
  local out="$1"; shift
  local n=$# t
  {
    printf '\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    printf '\x02\x00\x3e\x00\x01\x00\x00\x00'          # e_type, e_machine, e_version
    printf '\x00\x00\x00\x00\x00\x00\x00\x00'          # e_entry
    printf '\x40\x00\x00\x00\x00\x00\x00\x00'          # e_phoff = 64
    printf '\x00\x00\x00\x00\x00\x00\x00\x00'          # e_shoff
    printf '\x00\x00\x00\x00\x40\x00\x38\x00'          # e_flags, e_ehsize, e_phentsize
    printf "\\x$(printf %02x "$n")\\x00\\x00\\x00\\x00\\x00\\x00\\x00" # e_phnum, sh*
    for t in "$@"; do
      printf "\\x$(printf %02x "$t")\\x00\\x00\\x00"
      head -c 52 /dev/zero
    done
  } >"$out"
  chmod +x "$out"
}

# debugfs_cat IMAGE PATH — print a file from an ext4 image (no mount).
debugfs_cat() { debugfs -R "cat $2" "$1" 2>/dev/null; }
# debugfs_mode IMAGE PATH — octal permission bits (e.g. 0755).
debugfs_mode() { debugfs -R "stat $2" "$1" 2>/dev/null | sed -n 's/.*Mode: *\(0[0-7]*\).*/\1/p' | head -n1; }
debugfs_exists() { debugfs -R "stat $2" "$1" 2>/dev/null | grep -q 'Inode:'; }
# debugfs_owner IMAGE PATH — "uid:gid" of PATH in an ext4 image.
debugfs_owner() { debugfs -R "stat $2" "$1" 2>/dev/null | sed -n 's/.*User: *\([0-9]*\) *Group: *\([0-9]*\).*/\1:\2/p' | head -n1; }

# Same PT_INTERP check the image builders use (firecracker/private/mk*.sh).
# --- ELF helpers (coreutils `od` only; no libmagic `file`) ---------------
# is_elf FILE: true iff FILE starts with the ELF magic.
is_elf() { [ "$(od -An -c -N4 "$1" 2>/dev/null | tr -d ' ')" = '177ELF' ]; }
# elf_is_dynamic FILE: true iff the ELF has a PT_INTERP program header, i.e.
# needs a dynamic loader + libc at runtime. Static and static-pie binaries
# have none. Little-endian ELF only (x86_64, aarch64).
elf_is_dynamic() {
  local f="$1" cls phoff phentsize phnum i type
  rd() { od --endian=little -An -t "u$2" -j "$1" -N "$2" "$f" | tr -d ' '; }
  cls="$(rd 4 1)"
  if [ "$cls" = 2 ]; then
    phoff="$(rd 32 8)"; phentsize="$(rd 54 2)"; phnum="$(rd 56 2)"
  else
    phoff="$(rd 28 4)"; phentsize="$(rd 42 2)"; phnum="$(rd 44 2)"
  fi
  for ((i = 0; i < phnum; i++)); do
    type="$(rd $((phoff + i * phentsize)) 4)"
    [ "$type" = 3 ] && return 0
  done
  return 1
}
# --------------------------------------------------------------------------
