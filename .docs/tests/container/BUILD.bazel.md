<!-- docdaemon ts:2026-10-10T19:05:00Z hash:8a92c98cbffacff5 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines a two-layer OCI image and a Firecracker microVM configuration to test container boot, environment propagation, and AUFS whiteout behavior.

### Purpose
The file constructs a minimal Linux container image using `rules_oci` and validates it within a Firecracker VM via `firecracker_test`. It specifically verifies that layer overlays (whiteouts) and custom arguments are correctly applied at runtime.

### Key Components

#### Image Construction (`oci_image`)
*   **Layer 1**: Created by `genrule("layer1")`, this layer includes the entrypoint script (`run.sh`) and a placeholder file (`removed.txt`).
*   **Layer 2**: Created by `genrule("layer2")`, this layer introduces an AUFS whiteout file (`.wh.removed.txt`) to delete `removed.txt` from Layer 1 and adds a new file (`layer2.txt`).
*   **Configuration**: The resulting image sets the working directory to `/app`, defines an entrypoint using BusyBox, and injects the `GREETING` environment variable.

#### VM Definition (`firecracker_container`)
*   **Name**: `container_vm`
*   **Specs**: Configured with 128 MiB memory and a 32 MB disk size.
*   **Overrides**: Passes `extra_args` and `EXTRA_ENV` to the container runtime, demonstrating parameter injection into the VM lifecycle.

#### Validation (`firecracker_test`)
*   **Name**: `container_test`
*   **Assertions**: Uses `expect_markers` to verify successful boot and correct state:
    *   Environment variables (`GREETING`, `EXTRA_ENV`) are present.
    *   Command-line arguments (`from-cmd`, `extra arg`) are parsed correctly.
    *   File system operations work as expected (`WHITEOUT_APPLIED`, `LAYER2=from-layer-2`).
    *   The container exits with code 7, which is explicitly checked.
*   **Negative Testing**: Ensures `WHITEOUT_IGNORED` does not appear, confirming whiteouts are processed correctly.