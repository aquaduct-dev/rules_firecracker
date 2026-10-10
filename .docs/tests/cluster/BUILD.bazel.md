<!-- docdaemon ts:2026-10-10T19:04:57Z hash:cc3213c265b101c6 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines a Bazel test suite for multi-VM Firecracker scenarios, including networking, k3s clustering, IP renumbering, and disk installation.

It loads custom `firecracker` macros to orchestrate microVMs on a host bridge using `/dev/kvm`. All tests are tagged `manual` and `local`, requiring explicit invocation via the `:cluster` test suite or CI configurations. Each test isolates itself in a unique subnet to allow concurrent execution.

### Test Suites and VM Definitions
The file defines four distinct cluster scenarios:

1.  **Nettest**: Two VMs ping each other over a bridge. It uses a custom initramfs (`nettest_initrd`) and verifies connectivity via the `NETOK` marker.
2.  **k3s Cluster**: A 3-node Kubernetes cluster (1 server, 2 agents). It builds a rootfs using `mkk3srootfs` with busybox and k3s binaries. The test waits for the `K3SC_CLUSTER_READY` marker.
3.  **Renumber**: Tests persistent disk survival across subnet changes. It boots two nodes, then reboots them onto a new subnet, verifying healing via the `RN_HEAL_OK` marker.
4.  **Install-to-Disk**: Installs an OS from an initial rootfs to a GPT disk, then boots from it. It uses a shell script installer and verifies success via the `INSTALL_BOOT_OK` marker.

### Configuration Details
*   **Subnets**: Each scenario uses a distinct `/24` subnet (e.g., `10.211.56.0/24`) to prevent conflicts.
*   **Resources**: VMs are allocated specific memory (`mem_mib`) and vCPUs. The k3s server requires more resources (1536 MiB, 2 vCPUs) than others.
*   **Secrets**: The install test includes a `secret` parameter for authentication. This value is passed directly to the test macro; ensure sensitive values are managed securely if this file is shared.
*   **Timeouts**: Tests have varying timeouts, ranging from 60 seconds for simple network checks to 360 seconds for the k3s cluster initialization.