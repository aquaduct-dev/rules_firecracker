#!/bin/busybox sh
# /sbin/init for the renumber test (rootfs mode; cmdline has `rw`).
# Phase 1: no identity on the persistent disk (/dev/vdb) yet -> record our
# IP there. Phase 2: identity found -> we were renumbered; prove the new
# network works by pinging the peer, then print the heal marker carrying
# the OLD IP read back from the persistent disk.
bb=/bin/busybox
$bb mkdir -p /proc /sys /dev /persist
$bb mount -t proc proc /proc
$bb mount -t sysfs sysfs /sys
$bb mount -t devtmpfs devtmpfs /dev
$bb ip link set lo up
CMDLINE="$($bb cat /proc/cmdline)"
SELF="$(echo "$CMDLINE" | $bb sed -n 's/.*[ ]ip=\([0-9.]*\)::.*/\1/p')"
PEER="$(echo "$CMDLINE" | $bb sed -n 's/.*fc\.peer=\([0-9.]*\).*/\1/p')"

ping_peer() {
  i=0
  while [ "$i" -lt 20 ]; do
    $bb ping -c1 -W1 "$PEER" >/dev/null 2>&1 && return 0
    i=$((i + 1)); $bb sleep 1
  done
  return 1
}

if ! $bb mount -t ext4 /dev/vdb /persist; then
  echo "RN_PERSIST_MOUNT_FAILED"
elif [ -f /persist/ip ]; then
  OLD="$($bb cat /persist/ip)"
  ID="$($bb cat /persist/id)"
  if ping_peer; then
    echo "RN_HEAL_OK old=$OLD new=$SELF id=$ID"
  else
    echo "RN_HEAL_FAILED old=$OLD new=$SELF (peer $PEER unreachable)"
  fi
else
  ID="$($bb cat /proc/sys/kernel/random/uuid)"
  echo "$ID" >/persist/id
  echo "$SELF" >/persist/ip
  ping_peer && echo "RN_FORMED ip=$SELF id=$ID" || echo "RN_FORM_FAILED ip=$SELF"
fi
$bb sync
$bb umount /persist 2>/dev/null
$bb reboot -f
