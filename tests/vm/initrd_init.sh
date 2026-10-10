#!/bin/sh
# PID 1 of the initrd boot test: prove the initramfs layout (busybox applets,
# `files`, `execs`), the machine config (vCPUs, memory) and print markers.
mount -t proc proc /proc
mount -t sysfs sysfs /sys
echo "HELLO_FROM_INITRD"
echo "GREETING=$(cat /etc/greeting)"
# `execs` entry: a second copy of the static busybox under /opt.
# (named busybox so the multi-call binary runs as itself)
if /opt/bin/busybox true; then echo "STATIC_EXEC_OK"; fi
[ -x /init ] && echo "INIT_IS_EXECUTABLE"
echo "NPROC=$(grep -c '^processor' /proc/cpuinfo)"
mem_kb="$(sed -n 's/^MemTotal: *\([0-9]*\) kB/\1/p' /proc/meminfo)"
# mem_mib = 192 in BUILD; the kernel reserves some, so just check > 150 MiB
# and < 192 MiB.
if [ "$mem_kb" -gt 153600 ] && [ "$mem_kb" -le 196608 ]; then echo "MEM_OK"; else echo "MEM_BAD=$mem_kb"; fi
grep -q 'fctest.flag=1' /proc/cmdline && echo "CMDLINE_OK"
echo "INITRD_DONE"
# With reboot=k on the cmdline, a guest reboot makes firecracker exit.
reboot -f
