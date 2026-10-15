"""Bazel rules for booting real Linux VMs in your tests, using Firecracker.

```starlark
load(
    "@rules_firecracker//firecracker:defs.bzl",
    "firecracker_initramfs",
    "firecracker_microvm",
    "firecracker_test",
)
```

To build boot images, use `firecracker_initramfs` or `firecracker_rootfs`.
To get a VM you can run, use `firecracker_microvm`, or `firecracker_container`
for an OCI image. For tests, use `firecracker_test` for one VM,
`firecracker_k3s_test` to test against k3s, and `firecracker_cluster_test`,
`firecracker_renumber_test` or `firecracker_install_cluster_test` for
several VMs on one network.
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
