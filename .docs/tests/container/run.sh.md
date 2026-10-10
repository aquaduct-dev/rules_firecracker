<!-- docdaemon ts:2026-10-10T19:04:59Z hash:6feadb9b63692fbc model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script serves as the entrypoint for the `firecracker_container` test image, validating environment variables and file system layer behavior within a BusyBox shell.

### Purpose
The script verifies that the container runtime correctly propagates environment variables and handles overlay filesystem features, specifically whiteout files and lower-layer data access. It is designed to fail with exit code 7 to signal test outcomes or errors in the integration suite.

### Key Behaviors
- **Environment Inspection**: Prints the current process ID (`$$`), working directory, and values of `GREETING` and `EXTRA_ENV`.
- **Argument Logging**: Outputs the argument count (`$#`) and arguments (`$*`).
- **Whiteout Verification**: Checks for the existence of `/app/removed.txt`. If present, it prints `WHITEOUT_IGNORED`; if absent (correctly removed by the overlay), it prints `WHITEOUT_APPLIED`.
- **Layer Access**: Reads content from `/app/layer2.txt` using the shell builtin `read`, confirming access to underlying layers despite symlinks being unavailable.
- **Termination**: Exits with status code 7 regardless of success or failure, likely used by the test harness to detect execution completion.