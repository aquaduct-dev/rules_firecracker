<!-- docdaemon ts:2026-10-10T19:05:24Z hash:40a2a2948b5de4a4 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This script serves as a controlled hang scenario for testing VM timeout and early-exit mechanisms.

It prints the `HANG_START` marker to signal initialization completion, then enters an infinite loop sleeping for one second per iteration. This ensures the guest OS remains active but unresponsive, allowing host-side logic to detect the hang via timeouts rather than guest shutdown signals.