<!-- docdaemon ts:2026-10-10T19:05:00Z hash:b5d296c2526b6846 model:openrouter/qwen/qwen3.7-flash -->
## TL;DR
This file defines a no-op ConfigMap used as the scenario file that the launcher passes to the guest test via `--scenario`.

### Purpose
The `k3s_extras.yaml` file is the scenario file of `//tests/k3s:k3s_extras_test`. Its primary function is not to configure the cluster, but to be present at a specific path (`/etc/manifests/k3s_extras.yaml`) on the guest VM. The guest test's `flags.scenario` check verifies the launcher's flag contract: `--scenario` must equal `/etc/manifests/k3s_extras.yaml` and that file must exist. It does not gate or select any other checks.

### Structure
- **Kind**: `ConfigMap`
- **Name**: `fc-scenario`
- **Namespace**: `default`
- **Data**: Empty (`{}`)

Although defined as a Kubernetes resource, applying this file is effectively a no-op regarding cluster state because it contains no data and is not consumed by any controllers. It exists solely to ensure the file is deployed to the expected location on the node.

### Integration
1. **Deployment**: This manifest is applied during the test setup phase.
2. **Verification**: The guest test checks that `--scenario` is `/etc/manifests/k3s_extras.yaml` and that the file exists.
3. **Execution**: All other checks run regardless; if the scenario check fails it is recorded as a failed condition in the report.