#!/bin/busybox sh
# /sbin/init of the hello rootfs. The image has only busybox and this script:
# create the mount points (the cmdline has `rw`), then print a marker.
/bin/busybox mkdir -p /proc
/bin/busybox mount -t proc proc /proc
echo "HELLO_FROM_ROOTFS"
/bin/busybox reboot -f
