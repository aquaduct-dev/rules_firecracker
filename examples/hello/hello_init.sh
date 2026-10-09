#!/bin/sh
# /init (PID 1) of the hello initramfs: print a marker and the greeting,
# then reboot, which (with reboot=k on the cmdline) makes firecracker exit.
mount -t proc proc /proc
echo "HELLO_FROM_INITRD"
echo "GREETING=$(cat /etc/greeting)"
reboot -f
