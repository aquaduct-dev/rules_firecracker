"""Public API of rules_firecracker: build and test Firecracker microVMs.

```starlark
load(
    "@rules_firecracker//firecracker:defs.bzl",
    "firecracker_initramfs",
    "firecracker_microvm",
    "firecracker_test",
)
```

Images: `firecracker_initramfs`, `firecracker_rootfs`.
VMs: `firecracker_microvm`, `firecracker_container`.
Tests: `firecracker_test`, `firecracker_k3s_test`, and the multi-VM
`firecracker_cluster_test`, `firecracker_renumber_test`,
`firecracker_install_cluster_test`.
"""

load(
    "//firecracker/private:macros.bzl",
    _DEFAULT_KERNEL_CMDLINE = "DEFAULT_KERNEL_CMDLINE",
    _firecracker_cluster_test = "firecracker_cluster_test",
    _firecracker_container = "firecracker_container",
    _firecracker_initramfs = "firecracker_initramfs",
    _firecracker_install_cluster_test = "firecracker_install_cluster_test",
    _firecracker_k3s_test = "firecracker_k3s_test",
    _firecracker_microvm = "firecracker_microvm",
    _firecracker_renumber_test = "firecracker_renumber_test",
    _firecracker_rootfs = "firecracker_rootfs",
    _firecracker_test = "firecracker_test",
)

DEFAULT_KERNEL_CMDLINE = _DEFAULT_KERNEL_CMDLINE

firecracker_initramfs = _firecracker_initramfs
firecracker_rootfs = _firecracker_rootfs
firecracker_microvm = _firecracker_microvm
firecracker_test = _firecracker_test
firecracker_container = _firecracker_container
firecracker_k3s_test = _firecracker_k3s_test
firecracker_cluster_test = _firecracker_cluster_test
firecracker_renumber_test = _firecracker_renumber_test
firecracker_install_cluster_test = _firecracker_install_cluster_test
