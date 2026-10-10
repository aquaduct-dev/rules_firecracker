#!/bin/sh
# Prints one marker and then never exits or powers off: only the host-side
# timeout / early-exit logic can end this VM.
echo "HANG_START"
while true; do sleep 1; done
