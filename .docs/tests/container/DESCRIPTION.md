<!-- docdaemon ts:2026-10-10T19:05:51Z hash:dca317a81a5cfec3 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This directory contains integration tests for validating container boot, environment propagation, and AUFS whiteout behavior within a Firecracker microVM.

## Overview
The `tests/container` directory defines a comprehensive test suite that constructs a minimal Linux container image and runs it inside a simulated Firecracker VM. Its primary purpose is to verify that the build system correctly handles multi-layer OCI images, specifically focusing on overlay filesystem mechanics like whiteout files. Additionally, it ensures that custom environment variables and command-line arguments are accurately propagated from the host configuration into the guest container runtime.

## Deep Dive
### Image Construction
The test relies on a two-layer OCI image built via `rules_oci`. Layer 1 establishes the base state with an entrypoint script and a placeholder file (`removed.txt`). Layer 2 introduces an AUFS whiteout file (`.wh.removed.txt`) designed to delete `removed.txt` from the previous layer while adding new content (`layer2.txt`). This structure explicitly tests the overlay filesystem's ability to handle deletions across layers. The image configuration sets the working directory to `/app`, uses BusyBox as the entrypoint, and injects the `GREETING` environment variable.

### VM Configuration
A `firecracker_container` target named `container_vm` defines the execution environment. It allocates 128 MiB of memory and a 32 MB disk. Crucially, this component demonstrates parameter injection by passing `extra_args` and `EXTRA_ENV` to the container runtime, allowing the test to validate dynamic configuration at startup.

### Validation Logic
The `firecracker_test` target executes the assertions. It uses `expect_markers` to confirm successful boot and specific runtime states. Checks include verifying the presence of `GREETING` and `EXTRA_ENV`, parsing command-line arguments (`from-cmd`, `extra arg`), and confirming file system integrity. Specifically, it asserts that `WHITEOUT_APPLIED` appears (indicating `removed.txt` was successfully deleted) and `WHITEOUT_IGNORED` does not appear. The test concludes with exit code 7, signaling completion to the harness.

## Key Interfaces
*   `oci_image`: Defines the multi-layer container image structure and metadata.
*   `firecracker_container`: Configures the virtual machine specs and runtime overrides.
*   `firecracker_test`: Executes the validation logic against the running container.

## Dependencies
*   `rules_oci`: For constructing the OCI image layers.
*   `firecracker_test`: For simulating the microVM environment.
*   BusyBox: Used as the minimal shell and utilities within the container.

## Subcomponents
*   `BUILD.bazel`: Build definitions for the image, VM, and test targets.
*   `run.sh`: Entrypoint script for environment and filesystem verification.