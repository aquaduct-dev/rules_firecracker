#!/usr/bin/env bash
# Stand-in for the firecracker VMM, used via the microvm macros'
# `firecracker` attribute. Records how the launcher invoked it instead of
# booting anything.
if [[ "${1:-}" == --version ]]; then echo "Firecracker vFAKE"; exit 0; fi
echo "FAKE_FIRECRACKER_ARGS=$*"
cfg=""
while [[ $# -gt 0 ]]; do
  case "$1" in --config-file) cfg="$2"; shift 2 ;; *) shift ;; esac
done
[[ -n "${FAKE_FC_DUMP:-}" ]] && cp "$cfg" "$FAKE_FC_DUMP/vm.json" && pwd >"$FAKE_FC_DUMP/cwd"
for f in vmlinux.bin initrd.cpio.gz rootfs.ext4 extra.img; do
  [[ -e "$f" ]] && echo "RESOLVES:$f"
done
[[ -w rootfs.ext4 ]] && echo "ROOTFS_WRITABLE_COPY"
[[ -n "${FAKE_FC_SLEEP:-}" ]] && sleep "$FAKE_FC_SLEEP"
exit "${FAKE_FC_EXIT:-0}"
