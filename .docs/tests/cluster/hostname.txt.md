<!-- docdaemon ts:2026-10-10T19:04:53Z hash:389b46f0445738f6 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file serves as a static configuration fixture containing the hostname for the test node.

It provides a single-line string (`node`) used by the cluster testing suite to identify or mock the current host environment. This allows tests to verify hostname resolution, network binding, and cluster formation logic without relying on the actual system's hostname, ensuring deterministic and reproducible test results across different execution environments.