#!/usr/bin/env bash
# Firecracker microVM launcher (template). The firecracker_microvm macro
# substitutes @@SENTINEL@@ tokens at build time. At runtime the script
# resolves kernel/boot artifacts via runfiles, materializes a vm.json,
# and execs firecracker. If FC_TIMEOUT is set, the VM is killed after
# that many seconds and exit 0 is returned (firecracker_test relies on
# this so the boot itself doesn't have to gracefully shut down).

set -uo pipefail

# --- runfiles.bash bootstrap (canonical Bazel boilerplate) ---
if [[ -z "${RUNFILES_DIR:-}" ]]; then
  if [[ -d "${BASH_SOURCE[0]}.runfiles" ]]; then
    RUNFILES_DIR="${BASH_SOURCE[0]}.runfiles"
  elif [[ -d "$0.runfiles" ]]; then
    RUNFILES_DIR="$0.runfiles"
  fi
fi
if [[ -z "${RUNFILES_DIR:-}" && -n "${TEST_SRCDIR:-}" ]]; then
  RUNFILES_DIR="$TEST_SRCDIR"
fi
export RUNFILES_DIR
# shellcheck disable=SC1091
source "$RUNFILES_DIR/bazel_tools/tools/bash/runfiles/runfiles.bash" \
  || { echo "runner: cannot source runfiles.bash" >&2; exit 1; }

KERNEL="$(rlocation '@@KERNEL_RLOC@@')"
BOOT="$(rlocation '@@BOOT_RLOC@@')"
[[ -n "$KERNEL" && -f "$KERNEL" ]] || { echo "runner: kernel not found at @@KERNEL_RLOC@@" >&2; exit 1; }
[[ -n "$BOOT"   && -f "$BOOT"   ]] || { echo "runner: boot artifact not found at @@BOOT_RLOC@@" >&2; exit 1; }

WORK="$(mktemp -d -t fc-microvm.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# Symlink artifacts into a clean working dir; firecracker's path
# resolver doesn't love runfiles paths with ../external/... in them.
ln -sf "$KERNEL" "$WORK/vmlinux.bin"
case "@@BOOT_KIND@@" in
  initrd)
    ln -sf "$BOOT" "$WORK/initrd.cpio.gz"
    cat > "$WORK/vm.json" <<JSON
{
  "boot-source": {
    "kernel_image_path": "vmlinux.bin",
    "initrd_path": "initrd.cpio.gz",
    "boot_args": "@@KERNEL_CMDLINE@@"
  },
  "drives": [],
  "machine-config": {
    "vcpu_count": @@VCPUS@@,
    "mem_size_mib": @@MEM_MIB@@
  }
}
JSON
    ;;
  rootfs)
    # Firecracker opens non-readonly block devices RW; bazel-bin outputs
    # are 0444 so we copy (not symlink) into $WORK and make it writable.
    cp "$BOOT" "$WORK/rootfs.ext4"
    chmod 0644 "$WORK/rootfs.ext4"
    cat > "$WORK/vm.json" <<JSON
{
  "boot-source": {
    "kernel_image_path": "vmlinux.bin",
    "boot_args": "@@KERNEL_CMDLINE@@ root=/dev/vda"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "rootfs.ext4",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "machine-config": {
    "vcpu_count": @@VCPUS@@,
    "mem_size_mib": @@MEM_MIB@@
  }
}
JSON
    ;;
  *)
    echo "runner: unknown boot kind: @@BOOT_KIND@@" >&2
    exit 2
    ;;
esac

cd "$WORK"

if [[ -n "${FC_TIMEOUT:-}" ]]; then
  set +e
  timeout --foreground -s KILL "${FC_TIMEOUT}" firecracker --no-api --config-file vm.json
  rc=$?
  set -e
  # 124 = timeout reached, 137 = killed (128+9). Both are intentional kills.
  if [[ $rc -eq 124 || $rc -eq 137 ]]; then
    exit 0
  fi
  exit $rc
fi

exec firecracker --no-api --config-file vm.json
