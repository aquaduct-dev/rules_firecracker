# rules_firecracker

Bazel rules for building [Firecracker](https://firecracker-microvm.github.io/)
microVM images and running tests inside them: initramfs and ext4 rootfs
builders, a pinned 6.1 guest kernel, a runnable `firecracker_microvm`, and
test macros up to multi-node k3s clusters booted on a host bridge.

See [`defs.bzl`](defs.bzl) for the public API (`firecracker_initramfs`,
`firecracker_rootfs`, `firecracker_microvm`, `firecracker_test`,
`firecracker_container`, `firecracker_k3s_test`, `firecracker_cluster_test`, ...).

## Use

```starlark
# MODULE.bazel
bazel_dep(name = "rules_firecracker")
git_override(
    module_name = "rules_firecracker",
    remote = "https://github.com/aquaduct-dev/rules_firecracker.git",
    commit = "<sha>",
)
```

```starlark
load("@rules_firecracker//:defs.bzl", "firecracker_k3s_test")
```

Tests are tagged `requires-kvm`; copy the `kvm` config from [`.bazelrc`](.bazelrc)
into your own and run them with `bazel test --config=kvm`.

## Host requirements

- x86_64 Linux with `/dev/kvm` and a `firecracker` binary on `PATH`.
- `//:vmlinux` builds the kernel with the host toolchain (`gcc make bc flex
  bison libelf-dev libssl-dev`); ~5-10 min cold.
- Rootfs builders need `e2fsprogs` >= 1.43; the cluster tests need
  passwordless `sudo` for bridge/TAP setup and skip without it.
