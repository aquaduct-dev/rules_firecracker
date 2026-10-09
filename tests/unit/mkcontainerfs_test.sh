#!/usr/bin/env bash
# Unit test for //firecracker:mkcontainerfs (firecracker_container): builds a
# two-layer OCI layout by hand (gzip + plain layers, file whiteout, opaque
# dir) and checks the flattened rootfs and generated /sbin/init.
set -uo pipefail
source "${RUNFILES_DIR:-$TEST_SRCDIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
source "$(rlocation _main/tests/unit/testlib.sh)"

MK="$(rlocation _main/firecracker/mkcontainerfs)"
BB="$(rlocation "$BUSYBOX_RLOC")"

# blob FILE -> moves FILE into the layout, prints "sha256:<hex> <size>"
L="$T/layout"; mkdir -p "$L/blobs/sha256"
blob() { local h; h="$(sha256sum "$1" | cut -d' ' -f1)"; cp "$1" "$L/blobs/sha256/$h"; echo "sha256:$h $(stat -c %s "$1")"; }

mklayout() { # mklayout CONFIG_JSON
  mkdir -p "$T/l1/app" "$T/l1/etc/opaque" "$T/l2/app" "$T/l2/etc/opaque"
  printf 'echo run\n' >"$T/l1/app/run.sh"
  echo old >"$T/l1/app/old.txt"
  echo a >"$T/l1/etc/opaque/a.txt"
  : >"$T/l2/app/.wh.old.txt"
  : >"$T/l2/etc/opaque/.wh..wh..opq"
  echo b >"$T/l2/etc/opaque/b.txt"
  tar -C "$T/l1" -czf "$T/l1.tar.gz" .
  tar -C "$T/l2" -cf "$T/l2.tar" .
  read -r d1 s1 < <(blob "$T/l1.tar.gz")
  read -r d2 s2 < <(blob "$T/l2.tar")
  printf '%s' "$1" >"$T/config.json"
  read -r dc sc < <(blob "$T/config.json")
  cat >"$T/manifest.json" <<JSON
{"schemaVersion":2,"mediaType":"application/vnd.oci.image.manifest.v1+json",
 "config":{"mediaType":"application/vnd.oci.image.config.v1+json","digest":"$dc","size":$sc},
 "layers":[{"mediaType":"application/vnd.oci.image.layer.v1.tar+gzip","digest":"$d1","size":$s1},
           {"mediaType":"application/vnd.oci.image.layer.v1.tar","digest":"$d2","size":$s2}]}
JSON
  read -r dm sm < <(blob "$T/manifest.json")
  cat >"$L/index.json" <<JSON
{"schemaVersion":2,"manifests":[{"mediaType":"application/vnd.oci.image.manifest.v1+json","digest":"$dm","size":$sm}]}
JSON
  echo '{"imageLayoutVersion":"1.0.0"}' >"$L/oci-layout"
}

mklayout '{"architecture":"amd64","os":"linux","config":{"Env":["PATH=/bin","A=from-image"],"Entrypoint":["/sbin/busybox","sh"],"Cmd":["/app/run.sh"],"WorkingDir":"/app"}}'

"$MK" --out "$T/c.ext4" --image-dir "$L" --busybox "$BB" --size-mb 16 --label container \
  --extra-env "A=from-extra" --extra-env "B=it's quoted" --extra-arg "arg with space" 2>"$T/err"
assert_rc 0 $? "flattens an OCI layout into ext4"
I="$T/c.ext4"
debugfs_exists "$I" /app/run.sh && pass "layer-1 file present" || fail "/app/run.sh missing"
debugfs_exists "$I" /app/old.txt && fail "whiteout ignored: /app/old.txt still present" || pass "file whiteout applied"
debugfs_exists "$I" /etc/opaque/a.txt && fail "opaque whiteout ignored" || pass "opaque dir whiteout applied"
debugfs_exists "$I" /etc/opaque/b.txt && pass "opaque dir keeps upper layer" || fail "/etc/opaque/b.txt missing"
debugfs -R "ls /app" "$I" 2>/dev/null | grep -q '\.wh\.' && fail ".wh. marker leaked" || pass "no .wh. markers left"
debugfs_exists "$I" /sbin/busybox && pass "/sbin/busybox installed" || fail "/sbin/busybox missing"
[[ "$(debugfs_mode "$I" /sbin/init)" == 0755 ]] && pass "/sbin/init 0755" || fail "/sbin/init mode"
debugfs_cat "$I" /sbin/init >"$T/init"
assert_contains "$T/init" "export A=from-image"
assert_contains "$T/init" "export A=from-extra"
assert_contains "$T/init" "export B='it'\"'\"'s quoted'"
assert_contains "$T/init" "cd /app"
assert_contains "$T/init" "/sbin/busybox sh /app/run.sh 'arg with space'"
assert_contains "$T/init" "FIRECRACKER_CONTAINER_READY"
assert_contains "$T/init" 'FIRECRACKER_CONTAINER_EXIT=$rc'
# extra env must come after (override) the image env
[[ "$(grep -n 'A=from-image' "$T/init" | cut -d: -f1)" -lt "$(grep -n 'A=from-extra' "$T/init" | cut -d: -f1)" ]] \
  && pass "extra_env overrides image Env" || fail "extra_env ordered before image Env"

# No Entrypoint/Cmd and no extra args: nothing to run -> error.
rm -rf "$L" "$T"/l1 "$T"/l2; mkdir -p "$L/blobs/sha256"
mklayout '{"config":{}}'
"$MK" --out "$T/e.ext4" --image-dir "$L" --busybox "$BB" --size-mb 16 --label c 2>"$T/err"
assert_rc nonzero $? "image with nothing to run is rejected"
assert_contains "$T/err" "no Entrypoint or Cmd"
"$MK" --out "$T/e2.ext4" --image-dir "$L" --busybox "$BB" --size-mb 16 --label c --extra-env NOEQUALS 2>"$T/err"
assert_rc 2 $? "--extra-env without '=' is rejected"

finish
