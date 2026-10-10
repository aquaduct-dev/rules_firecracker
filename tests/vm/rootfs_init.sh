#!/bin/busybox sh
# /sbin/init of the rootfs boot test. The image holds only busybox and this
# script (no mount points), so remount / read-write, create them, and call
# applets through busybox explicitly.
bb=/bin/busybox
$bb mount -o remount,rw /
$bb mkdir -p /proc /dev
$bb mount -t proc proc /proc
echo "HELLO_FROM_ROOTFS"
# / must be the ext4 image on /dev/vda.
$bb grep -qE '^/dev/(root|vda) / ext4 rw' /proc/mounts && echo "ROOT_IS_EXT4_VDA"
echo "ROOTFS_GREETING=$($bb cat /etc/rootfs-greeting)"
$bb sync
# With reboot=k on the cmdline, a guest reboot makes firecracker exit.
$bb reboot -f
