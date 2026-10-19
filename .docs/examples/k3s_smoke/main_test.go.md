<!-- docdaemon ts:2026-10-19T23:24:27Z hash:7f05364681ed3f98 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file contains unit tests for the `hasReady` function, which parses kubectl node status output to determine if any node is ready.

The test suite validates the logic of `hasReady`, ensuring it correctly identifies nodes with a "True" status while handling edge cases like empty output, missing tabs, or malformed lines. The implementation uses `strings.Split` and `strings.Cut` to parse tab-separated node names and statuses, replacing earlier hand-written splitting logic. This approach ensures consistent behavior across various input formats, including those with trailing newlines, blank lines, or partial data.