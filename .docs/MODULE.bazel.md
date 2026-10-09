<!-- docdaemon ts:2026-10-09T22:28:58Z hash:bee7a96544b25807 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines the `rules_firecracker` Bazel module and declares external dependencies for kernel, userland, and control plane binaries.

It configures the Go SDK via `rules_go` extensions to support the single Go-based self-test (`k3s_smoke`). It fetches three critical artifacts using `http_file`: a prebuilt Linux 6.1.155 kernel source (built locally with FUSE and entropy fixes), a static BusyBox binary for the initramfs, and a static k3s binary used as PID 1 in the microVM guest. All downloads are pinned by SHA-256 to ensure hermetic builds.