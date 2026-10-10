<!-- docdaemon ts:2026-10-10T19:05:00Z hash:127fc7cf4c2c6274 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines a ConfigMap fixture used to inject static test data into the Kubernetes cluster during K3s integration tests.

### Purpose
The `fixture.yaml` manifest creates a `ConfigMap` named `fc-fixture` in the `default` namespace. It serves as a deterministic reference point for verifying that extra manifests are correctly applied and accessible within the test environment.

### Key Components
- **Kind**: `ConfigMap`
- **Name**: `fc-fixture`
- **Namespace**: `default`
- **Data**: Contains a single key-value pair (`marker: from-extra-manifest`) to validate presence and content integrity.

### Integration Context
This resource is part of the `tests/k3s` suite. It is typically loaded via an "extra manifest" mechanism, allowing tests to confirm that custom resources are successfully deployed alongside the base K3s configuration without requiring dynamic generation at runtime.