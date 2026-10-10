#!/bin/busybox sh
# /sbin/init of a node booted from its INSTALLED disk (root=/dev/vda2, `rw`):
# check the root really is partition 2 of the GPT disk, read the settings the
# installer injected, and ping the peer node.
bb=/bin/busybox
$bb mkdir -p /proc /sys /dev
$bb mount -t proc proc /proc
$bb mount -t sysfs sysfs /sys
$bb ip link set lo up
CMDLINE="$($bb cat /proc/cmdline)"
SELF="$(echo "$CMDLINE" | $bb sed -n 's/.*[ ]ip=\([0-9.]*\)::.*/\1/p')"
PEER="$(echo "$CMDLINE" | $bb sed -n 's/.*fc\.peer=\([0-9.]*\).*/\1/p')"
# /proc/mounts says /dev/root; compare the root's device number instead.
ROOT_DEV="$($bb mountpoint -d /)"
VDA2_DEV="$($bb cat /sys/class/block/vda2/dev 2>/dev/null)"
ROOT="dev=$ROOT_DEV vda2=$VDA2_DEV"
echo "INSTALLED_NODE self=$SELF root=$ROOT"
SECRET="$($bb sed -n 's/^cluster_secret=//p' /etc/installed-settings 2>/dev/null)"
ok=0; i=0
while [ "$i" -lt 20 ]; do
  $bb ping -c1 -W1 "$PEER" >/dev/null 2>&1 && { ok=1; break; }
  i=$((i + 1)); $bb sleep 1
done
if [ "$ok" = 1 ] && [ -n "$SECRET" ] && [ -n "$VDA2_DEV" ] && [ "$ROOT_DEV" = "$VDA2_DEV" ]; then
  echo "INSTALL_BOOT_OK root=/dev/vda2 secret=${SECRET%${SECRET#????????}} peer=$PEER"
else
  echo "INSTALL_BOOT_FAILED ok=$ok secret=${SECRET:-none} root=$ROOT"
fi
$bb reboot -f
