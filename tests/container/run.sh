# Entrypoint of the firecracker_container test image (run by busybox sh).
echo "CONTAINER_PID=$$"
echo "CWD=$(pwd)"
echo "GREETING=$GREETING"
echo "EXTRA_ENV=$EXTRA_ENV"
echo "ARGC=$# ARGS=$*"
[ -e /app/removed.txt ] && echo "WHITEOUT_IGNORED" || echo "WHITEOUT_APPLIED"
read -r layer2 < /app/layer2.txt  # shell builtin: the image has no applet symlinks
echo "LAYER2=$layer2"
exit 7
