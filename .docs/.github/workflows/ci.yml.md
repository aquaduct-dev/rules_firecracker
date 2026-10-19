<!-- docdaemon ts:2026-10-10T19:04:45Z hash:c03759dbc8b1eb4f model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines the CI pipeline for building, testing, and validating the Firecracker rules across unit, integration, and end-to-end scenarios.

The workflow triggers on pushes to `main`, pull requests, and manual dispatches. It enforces concurrency limits to cancel redundant runs on the same branch or PR. The pipeline has five jobs. `unit` and `kernel` start at once; `vm`, `cluster` and `e2e` wait for `kernel` and restore the guest kernel it saved in the disk cache.

### Jobs

- **unit**: Runs fast feedback checks including static analysis, unit tests, and documentation generation. It does not require KVM access.
- **kernel**: Builds the guest Linux kernel (`vmlinux`) from both the root module and the e2e workspace perspective. It caches the resulting disk image in `~/.cache/fc-disk-cache` using a content-based key to accelerate downstream jobs.
- **vm**: Executes all non-manual tests, including single-VM boots, failure paths, container support, k3s single-node, and examples. It requires KVM and depends on the `kernel` job. Test logs are uploaded as artifacts on failure.
- **cluster**: Runs multi-VM rig tests (2-VM ping, 3-node k3s cluster, persistent disks) on a host bridge. These tests require elevated privileges (`sudo`) and KVM. They run sequentially (`--local_test_jobs=1`) due to high memory usage. Logs are uploaded on failure.
- **e2e**: Validates the rules when consumed as an external module via `local_path_override`, mirroring how users and the BCR test module interact with the codebase.