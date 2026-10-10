#!/bin/sh
# PID 1 of the e2e smoke microVM.
mount -t proc proc /proc
echo "E2E_SMOKE_OK nproc=$(grep -c '^processor' /proc/cpuinfo)"
reboot -f
