#!/bin/sh
# initrd + extra_drive: the drive is /dev/vda. Read a file the image was
# built with, then prove the drive is writable.
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null
mkdir -p /mnt
if mount -t ext4 /dev/vda /mnt; then
  echo "PAYLOAD=$(cat /mnt/data/payload.txt)"
  echo written > /mnt/data/new.txt && sync && echo "EXTRA_DRIVE_WRITABLE"
  umount /mnt
  mount -t ext4 -o ro /dev/vda /mnt && [ "$(cat /mnt/data/new.txt)" = written ] && echo "EXTRA_DRIVE_PERSISTED"
  umount /mnt
else
  echo "EXTRA_DRIVE_MOUNT_FAILED"
fi
# With reboot=k on the cmdline, a guest reboot makes firecracker exit.
reboot -f
