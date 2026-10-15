# rules_firecracker

Bazel rules for booting real Linux VMs in your tests.

They use [Firecracker](https://firecracker-microvm.github.io/) microVMs. You
can build a boot image, start a VM from it, and check what it prints. The
same rules scale up to a k3s cluster of several VMs on a shared network.

You don't need firecracker installed. The rules download a pinned release
(v1.17.0), check its sha256, and run that copy. The host still has to
provide a few things, like `/dev/kvm`. See [Host requirements](#host-requirements).

- [Setup](#setup)
- [Quick start](#quick-start)
- [API reference](#api-reference): [macros](#macros), [public targets](#public-targets), [tools](#image-builder-tools)
- [What guests print](#what-guests-print)
- [Running in GitHub Actions](#running-in-github-actions)
- [Host requirements](#host-requirements)
- [Working on this repo](#working-on-this-repo)

[docs/defs.md](docs/defs.md) has the same API reference, generated from the
docstrings.

## Setup

Add the module to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_firecracker")
git_override(
    module_name = "rules_firecracker",
    remote = "https://github.com/aquaduct-dev/rules_firecracker.git",
    commit = "<sha>",
)
```

Load the macros you need:

```starlark
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_test")
```

VM tests need `/dev/kvm` inside Bazel's sandbox. Add this to your `.bazelrc`:

```
build:kvm --sandbox_add_mount_pair=/dev/kvm
test:kvm --sandbox_add_mount_pair=/dev/kvm
```

Then run `bazel test --config=kvm //...`.

Your user needs read and write access to `/dev/kvm`. That usually means
being in the `kvm` group. On a machine without KVM, skip the VM tests with
`--test_tag_filters=-requires-kvm`. Every VM test has that tag.

## Quick start

This is [`examples/hello`](examples/hello/BUILD.bazel). It boots a tiny VM
and checks that it says hello.

```starlark
load(
    "@rules_firecracker//firecracker:defs.bzl",
    "firecracker_initramfs",
    "firecracker_microvm",
    "firecracker_test",
)

firecracker_initramfs(
    name = "hello_initrd",
    files = {"greeting.txt": "/etc/greeting"},
    init = "hello_init.sh",
)

firecracker_microvm(
    name = "hello_vm",
    initrd = ":hello_initrd",
    mem_mib = 128,
)

firecracker_test(
    name = "hello_test",
    expect_markers = [
        "HELLO_FROM_INITRD",
        "GREETING=hello, firecracker",
    ],
    microvm = ":hello_vm",
    unexpected_markers = ["Kernel panic"],
)
```

`hello_init.sh` runs as PID 1 inside the VM:

```sh
#!/bin/sh
mount -t proc proc /proc
echo "HELLO_FROM_INITRD"
echo "GREETING=$(cat /etc/greeting)"
reboot -f   # ends the VM, so firecracker exits
```

To boot the VM yourself and watch its console, run
`bazel run //examples/hello:hello_vm`.

## API reference

Load everything from `@rules_firecracker//firecracker:defs.bzl`. Default
labels below are relative to `@rules_firecracker`.

### Macros

| Macro | What you get |
| --- | --- |
| [`firecracker_initramfs`](#firecracker_initramfs) | An initramfs, `<name>.cpio.gz` |
| [`firecracker_rootfs`](#firecracker_rootfs) | An ext4 disk image, `<name>.ext4` |
| [`firecracker_microvm`](#firecracker_microvm) | A target you can `bazel run` to boot a VM |
| [`firecracker_test`](#firecracker_test) | A test that boots a VM and checks its console |
| [`firecracker_container`](#firecracker_container) | A VM that runs one OCI image |
| [`firecracker_k3s_test`](#firecracker_k3s_test) | A test that runs your code against k3s in a VM |
| [`firecracker_cluster_test`](#firecracker_cluster_test) | A test that boots several VMs on one network |
| [`firecracker_renumber_test`](#firecracker_renumber_test) | A cluster test that moves the VMs to new IPs and reboots them |
| [`firecracker_install_cluster_test`](#firecracker_install_cluster_test) | A cluster test that installs each node to disk, then boots the disks |

The module also exports `DEFAULT_KERNEL_CMDLINE`:
`console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on`.

The `reboot=k` part matters. With it, a guest that runs `reboot -f` ends the
firecracker process. That's how a guest says it's done. `poweroff` doesn't
work for this. It only halts the CPU, and the VM sits there until something
kills it.

Every macro passes extra keyword arguments through to the rule underneath
it (a `genrule`, `sh_binary` or `sh_test`).

#### firecracker_initramfs

Packs files into an initramfs (a gzip-compressed cpio archive).

The archive gets:

- a static busybox at `/bin/busybox`, with every applet linked into `/bin`
  and `init`, `mount`, `umount` and `sh` linked into `/sbin`
- your `init` at `/init`
- an `/etc/fstab`
- empty `/dev`, `/proc`, `/sys`, `/tmp` and `/run` directories

Packing uses busybox's own `cpio` and `gzip`, not the host's.

The initramfs has no libc, so dynamically linked programs can't run in it.
The build checks every ELF file in `execs` (and busybox itself) and fails
if one is dynamically linked.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The output is `<name>.cpio.gz`. |
| `init` | label | required | Script or static binary to run as PID 1. Installed at `/init` with mode 0755. |
| `files` | dict of label → absolute path | `{}` | Files to install with mode 0644. |
| `execs` | dict of label → absolute path | `{}` | Files to install with mode 0755. ELF files must be static. |
| `busybox` | label | `//firecracker:busybox_static` | The static busybox to use. |

No tags are added. See [Quick start](#quick-start) for an example.

#### firecracker_rootfs

Builds an ext4 disk image with `mkfs.ext4 -d`. It doesn't need root, a
mount, or a loop device.

The image holds only the files you list. There are no `/proc` or `/dev`
directories unless you add them. To boot it as the root filesystem:

1. Install a PID 1, like busybox plus an init script.
2. Add `rw init=/sbin/init` to the VM's kernel command line.
3. Have your init create `/proc` and the other mount points it needs.

You can also attach the image as a data disk with `extra_drive`.

The build step runs locally and the image isn't cached. That's because the
image is a sparse file, and a cache would store it at full size.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The output is `<name>.ext4`. |
| `size_mb` | int | required | Image size in MiB. The file is sparse. |
| `label` | string | required | ext4 volume label, 16 characters at most. |
| `files` | dict of label → absolute path | `{}` | Files to install with mode 0644. |
| `execs` | dict of label → absolute path | `{}` | Files to install with mode 0755. |

```starlark
firecracker_rootfs(
    name = "hello_rootfs",
    execs = {
        "@rules_firecracker//firecracker:busybox_static": "/bin/busybox",
        "hello_rootfs_init.sh": "/sbin/init",
    },
    label = "hello",
    size_mb = 16,
)

firecracker_microvm(
    name = "hello_rootfs_vm",
    kernel_cmdline = DEFAULT_KERNEL_CMDLINE + " rw init=/sbin/init",
    mem_mib = 128,
    rootfs = ":hello_rootfs",
)
```

#### firecracker_microvm

Creates a target you can `bazel run` to boot a VM. The VM's console prints to
your terminal. The target is always tagged `manual`, so `//...` doesn't
build it unless something depends on it.

When you run it, it finds the kernel, the boot image and the firecracker
binary in its runfiles. It writes a `vm.json` config into a new temp
directory and runs `firecracker --no-api --config-file vm.json`.

Set exactly one of `initrd` or `rootfs`. That picks how the VM boots.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The target you run. |
| `kernel` | label | `//firecracker:vmlinux` | Uncompressed kernel ELF. |
| `initrd` | label | `None` | Boot from this initramfs. |
| `rootfs` | label | `None` | Boot from this ext4 image as `/dev/vda`. `root=/dev/vda` is added to the command line. The image is copied first, so the VM can write to it. |
| `extra_drive` | label | `None` | One more writable disk, copied first. It's `/dev/vda` when booting from an initrd and `/dev/vdb` when booting from a rootfs. |
| `kernel_cmdline` | string | `DEFAULT_KERNEL_CMDLINE` | Kernel boot arguments. |
| `vcpus` | int | `1` | Number of vCPUs. |
| `mem_mib` | int | `256` | Guest memory in MiB. |
| `firecracker` | label | `//firecracker:firecracker` | The firecracker binary to run. Point it at your own build to replace the pinned release. It must be a single executable file. |
| `visibility`, `tags` | | | Passed through. `manual` is always added. |

These environment variables change what the VM does when you run it:

| Variable | What it does |
| --- | --- |
| `FC_TIMEOUT=<s>` | Kills the VM after `<s>` seconds and exits 0. If firecracker exits on its own with an error, that error code comes through. |
| `FC_KEEP_WORK=1` | Keeps the temp directory and prints its path, so you can look at files like `extra.img` afterwards. |
| `FC_TAP`, `FC_GUEST_MAC` | Adds a network card connected to the host TAP device `FC_TAP`. The MAC defaults to `06:00:AC:10:00:02`. |
| `FC_CMDLINE_EXTRA` | Adds arguments to the kernel command line, like `ip=<ip>::<gw>:<mask>::eth0:off`. |
| `FC_PERSIST_DISK=<path>` | Rootfs mode only. Attaches this host file directly, without copying, as the last disk: `/dev/vdb`, or `/dev/vdc` if there's an `extra_drive`. Changes survive reboots. |
| `FC_BOOT_DISK=<path>`, `FC_ROOT_PART` | Boots from a partitioned disk image instead. The root partition defaults to `/dev/vda2`. |
| `FC_FIRECRACKER=<path>` | Runs this firecracker binary instead of the pinned one. Meant for debugging. |

See [Quick start](#quick-start) for a basic example.
[`tests/unit`](tests/unit/BUILD.bazel) uses the `firecracker` attribute to
swap in a fake firecracker:

```starlark
firecracker_microvm(
    name = "fake_initrd_vm",
    extra_drive = "fake_disk.img",
    firecracker = "fake_firecracker.sh",
    initrd = "fake_initrd.cpio.gz",
    kernel = "fake_kernel.bin",
    kernel_cmdline = "console=ttyS0 custom.arg=1",
    mem_mib = 96,
    vcpus = 3,
)
```

#### firecracker_test

A test that boots a VM and checks what it prints on its console.

Here's how it runs:

1. It boots the VM with `FC_TIMEOUT=timeout_seconds` and copies the console
   into the test log.
2. Once every expected marker has shown up, it kills the VM. A passing test
   usually takes a few seconds.
3. If the markers don't all show up, it waits for the VM to exit or time
   out. A timeout on its own doesn't fail the test.
4. It fails if any `expect_markers` string is missing, or if any
   `unexpected_markers` string appears. Matching is plain text, not regex.

It adds the tags `requires-kvm` and `no-cache`.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The test. |
| `microvm` | label | required | A `firecracker_microvm` or `firecracker_container`. |
| `expect_markers` | list of strings | `[]` | All of these must appear. |
| `unexpected_markers` | list of strings | `[]` | None of these may appear. |
| `timeout_seconds` | int | `30` | The longest the VM may run. |
| `size` | string | `"medium"` | Test size. |
| `visibility`, `tags` | | | Passed through, with the tags above added. |

See [Quick start](#quick-start) for an example.

#### firecracker_container

Boots one OCI image as the whole VM.

The image's layers are merged into an ext4 root filesystem. Deleted files
and opaque directories are handled. A static busybox goes in at
`/sbin/busybox`, and a generated `/sbin/init` replaces any init the image
has. That init:

1. mounts `/proc`, `/sys`, `/dev`, `/tmp` and `/run`
2. sets the image's `Env`, then your `extra_env`
3. changes to the image's `WorkingDir`
4. prints `FIRECRACKER_CONTAINER_READY`
5. runs `Entrypoint + Cmd + extra_args`
6. prints `FIRECRACKER_CONTAINER_EXIT=<exit code>`
7. reboots, which ends the VM

You get a `firecracker_microvm` named `name`, plus a helper target
`_<name>__rootfs` that builds the image.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The VM target. |
| `image` | label | required | An `oci_image`, or any target that produces an OCI image layout directory. |
| `size_mb` | int | `512` | Root filesystem size in MiB. It must be bigger than the merged image. |
| `kernel` | label | `//firecracker:vmlinux` | Guest kernel. |
| `extra_env` | dict of string → string | `{}` | Set after the image's `Env`, so these win. |
| `extra_args` | list of strings | `[]` | Added after `Entrypoint + Cmd`. |
| `kernel_cmdline` | string | `DEFAULT_KERNEL_CMDLINE + " init=/sbin/init"` | Kernel boot arguments. |
| `vcpus` | int | `1` | Number of vCPUs. |
| `mem_mib` | int | `512` | Guest memory in MiB. |
| `busybox` | label | `//firecracker:busybox_static` | Copied to `/sbin/busybox`. |
| `firecracker` | label | `//firecracker:firecracker` | The firecracker binary, as in `firecracker_microvm`. |
| `visibility`, `tags` | | | Passed through to the VM target. |

This is from [`tests/container`](tests/container/BUILD.bazel), using rules_oci:

```starlark
oci_image(
    name = "image",
    architecture = "amd64",
    cmd = ["from-cmd"],
    entrypoint = ["/sbin/busybox", "sh", "/app/run.sh"],
    env = {"GREETING": "hello-from-image-env"},
    os = "linux",
    tars = [":layer1", ":layer2"],
    workdir = "/app",
)

firecracker_container(
    name = "container_vm",
    extra_args = ["extra arg"],
    extra_env = {"EXTRA_ENV": "set-by-macro"},
    image = ":image",
    mem_mib = 128,
    size_mb = 32,
)

firecracker_test(
    name = "container_test",
    expect_markers = ["FIRECRACKER_CONTAINER_READY", "FIRECRACKER_CONTAINER_EXIT=7"],
    microvm = ":container_vm",
)
```

#### firecracker_k3s_test

Starts a single-node k3s server in a VM, then runs your test program inside
the VM against it. Your program writes a JSON report, and the test passes or
fails based on that. See [The k3s test report](#the-k3s-test-report) for the
format.

The VM's disk holds:

- busybox
- k3s at `/usr/local/bin/k3s`, with `kubectl`, `crictl` and `ctr` links
- your test program at `/usr/local/bin/<its target name>`
- the init script that runs it all

You get three targets: the test, `_<name>__microvm`, and
`_<name>__rootfs`. The test is tagged `requires-kvm` and `no-cache`.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The test. |
| `test_binary` | label | required | Your test program. It must be static, like a `go_binary` built without cgo. |
| `scenario` | string | required | A scenario name. It's written to `/etc/scenario` and passed as `--scenario=/etc/manifests/<scenario>.yaml`. |
| `extra_manifests` | dict of label → file name | `{}` | Copied into `/etc/manifests/` and applied with `kubectl apply` once k3s is ready. |
| `extra_images` | dict of label → file name | `{}` | Image tarballs, copied into `/etc/images/` and loaded into k3s before it starts. |
| `extra_files` | dict of label → absolute path | `{}` | Files to install with mode 0644. |
| `extra_execs` | dict of label → absolute path | `{}` | Files to install with mode 0755. |
| `timeout_seconds` | int | `300` | The longest the VM may run. |
| `vcpus` | int | `2` | Number of vCPUs. k3s needs at least 2. |
| `mem_mib` | int | `2048` | Guest memory in MiB. |
| `size_mb` | int | `2048` | Disk size in MiB. |
| `kernel` | label | `//firecracker:vmlinux` | Guest kernel. |
| `kernel_cmdline` | string | `DEFAULT_KERNEL_CMDLINE` | Kernel boot arguments. |
| `busybox` | label | `//firecracker:busybox_static` | Static busybox. |
| `k3s` | label | `//firecracker:k3s_binary` | Static k3s. |
| `init` | label | `//firecracker:k3s_init` | The init script, installed at `/sbin/init`. |
| `firecracker` | label | `//firecracker:firecracker` | The firecracker binary, as in `firecracker_microvm`. |
| `size` | string | `"enormous"` | Test size. |
| `visibility`, `tags` | | | Passed through, with the tags above added. |

This is from [`examples/k3s_smoke`](examples/k3s_smoke/BUILD.bazel).
[`tests/k3s`](tests/k3s/BUILD.bazel) shows every `extra_*` attribute in use.

```starlark
go_binary(
    name = "k3s_smoke",
    embed = [":k3s_smoke_lib"],
)

firecracker_k3s_test(
    name = "k3s_smoke_test",
    scenario = "k3s_smoke",
    test_binary = ":k3s_smoke",
    timeout_seconds = 300,
)
```

#### firecracker_cluster_test

Boots several copies of one VM on a shared network and passes if any of
them prints `expect_marker`.

Here's how it runs:

1. It creates a Linux bridge on the host, with the address `subnet_gw`, and
   one TAP device per node.
2. It boots every node at the same time. Each one gets
   `ip=<IP>::<GW>:<MASK>::eth0:off <EXTRA>` on its kernel command line.
   See [Cluster node specs](#cluster-node-specs).
3. It waits for all the VMs to exit, or for `timeout_seconds`.
4. It removes the bridge and TAP devices.
5. It passes if `expect_marker` is in any node's console log.

The network setup needs root, so this test runs outside Bazel's sandbox
and calls `sudo -n ip ...` and `iptables`. It's tagged `requires-kvm`,
`no-cache`, `local`, `no-sandbox` and `manual`.

Because of `manual`, `bazel test //...` won't run it. Name it directly or
put it in a `test_suite`.

If `/dev/kvm` or passwordless sudo is missing, the test prints SKIP and
passes. Set `FC_NO_SKIP=1` in the test environment to make that a failure,
which is what you want in CI.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The test. |
| `vm` | label | required | The `firecracker_microvm` that every node boots. |
| `nodes` | list of strings | required | One [node spec](#cluster-node-specs) per VM. |
| `expect_marker` | string | required | Must appear in at least one node's log. |
| `leader_idx` | string | required | The node whose log is printed at the end. |
| `subnet_gw` | string | `"10.211.55.1/24"` | The bridge address in CIDR form. It's also the VMs' gateway. |
| `timeout_seconds` | int | `360` | The longest each VM may run. |
| `size` | string | `"enormous"` | Test size. |
| `visibility`, `tags` | | | Passed through, with the tags above added. |

If two cluster tests might run at the same time, give them different
subnets.

This is from [`tests/cluster`](tests/cluster/BUILD.bazel). Two VMs ping each
other:

```starlark
firecracker_cluster_test(
    name = "nettest_cluster_test",
    expect_marker = "NETOK 10.211.56.11->10.211.56.12",
    leader_idx = "1",
    nodes = [
        "1,10.211.56.11,06:00:AC:10:38:11,ofd.peer=10.211.56.12",
        "2,10.211.56.12,06:00:AC:10:38:12,ofd.peer=10.211.56.11",
    ],
    subnet_gw = "10.211.56.1/24",
    timeout_seconds = 60,
    vm = ":nettest_vm",
)
```

#### firecracker_renumber_test

Checks that a cluster recovers when its nodes come back on new IP
addresses. It runs in two phases, and each node keeps its own disk across
both.

1. Phase 1 boots `nodes1` on a bridge at `gw1`. Each node gets a 2 GiB ext4
   data disk at `/dev/vdb`.
2. Phase 2 boots `nodes2` on a bridge at `gw2`. The nodes keep the same
   IDs and MACs but get new IPs. Each one gets its disk from phase 1 back,
   matched by IDX.
3. The test passes if `expect_marker` shows up in a phase 2 log.

`vm` has to boot from a rootfs, because the data disk only works in that
mode. Tags, SKIP and `FC_NO_SKIP` work the same as in
`firecracker_cluster_test`.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The test. |
| `vm` | label | required | A `firecracker_microvm` that boots from a rootfs. |
| `nodes1`, `nodes2` | list of strings | required | Node specs for phase 1 and phase 2. |
| `gw1`, `gw2` | string | required | Bridge address for each phase, in CIDR form. |
| `expect_marker` | string | required | Must appear in a phase 2 log. |
| `timeout1`, `timeout2` | int | `240`, `300` | The longest each VM may run, per phase. |
| `size` | string | `"enormous"` | Test size. |
| `visibility`, `tags` | | | Passed through. |

This is from [`tests/cluster`](tests/cluster/BUILD.bazel):

```starlark
firecracker_renumber_test(
    name = "renumber_test",
    expect_marker = "RN_HEAL_OK old=10.211.58.11 new=10.211.59.11",
    gw1 = "10.211.58.1/24",
    gw2 = "10.211.59.1/24",
    nodes1 = [
        "1,10.211.58.11,06:00:AC:10:3A:11,fc.peer=10.211.58.12",
        "2,10.211.58.12,06:00:AC:10:3A:12,fc.peer=10.211.58.11",
    ],
    nodes2 = [
        "1,10.211.59.11,06:00:AC:10:3A:11,fc.peer=10.211.59.12",
        "2,10.211.59.12,06:00:AC:10:3A:12,fc.peer=10.211.59.11",
    ],
    timeout1 = 60,
    timeout2 = 60,
    vm = ":renumber_vm",
)
```

#### firecracker_install_cluster_test

Checks an installer end to end. It installs each node to a blank disk,
then boots the cluster from those disks.

Phase 1 runs once per node:

1. Create a sparse 5 GiB disk image and attach it with `sudo losetup -fP`.
2. Write a `settings.ini` like this:

   ```ini
   [node]
   role = server
   [cluster]
   cluster_secret = <secret>
   [install]
   target_disk = /dev/loopN
   wipe_confirm = yes-i-am-sure
   ```

3. Run `sudo <installer> --settings <settings.ini> --rootfs-image <rootfs>`.
   Your installer has to partition the disk and put a bootable root
   filesystem on partition 2.

Phase 2 boots every node from its disk (`root=/dev/vda2`) on a bridge at
`gw`. The test passes if `expect_marker` shows up in a log.

`vm` only supplies the kernel, the command line and the machine size. Its
own boot image isn't used. `installer` can be a `go_binary` or any other
single-file program, like an `sh_binary`.

The host also needs `losetup`, `sgdisk`, `mkfs.fat`, `mkfs.ext4` and
`mkfs.exfat`. Without them the test skips, or fails with `FC_NO_SKIP=1`.
Tags work the same as in `firecracker_cluster_test`.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The test. |
| `vm` | label | required | A `firecracker_microvm` to take the kernel, command line and size from. |
| `installer` | label | required | Your installer program. |
| `rootfs` | label | required | The root filesystem image passed to the installer. |
| `nodes` | list of strings | required | Node specs. |
| `expect_marker` | string | required | Must appear in a phase 2 log. |
| `gw` | string | `"10.211.55.1/24"` | Bridge address in CIDR form. |
| `secret` | string | 64 hex characters | Written as `cluster_secret` in each `settings.ini`. |
| `timeout_seconds` | int | `360` | The longest each VM may run in phase 2. |
| `size` | string | `"enormous"` | Test size. |
| `visibility`, `tags` | | | Passed through. |

[`tests/cluster`](tests/cluster/BUILD.bazel) tests it with a small `sgdisk`
and `dd` installer, [`installer.sh`](tests/cluster/installer.sh):

```starlark
firecracker_install_cluster_test(
    name = "install_cluster_test",
    expect_marker = "INSTALL_BOOT_OK root=/dev/vda2 secret=0123abcd peer=10.211.60.12",
    gw = "10.211.60.1/24",
    installer = ":installer",
    nodes = [
        "1,10.211.60.11,06:00:AC:10:3C:11,fc.peer=10.211.60.12",
        "2,10.211.60.12,06:00:AC:10:3C:12,fc.peer=10.211.60.11",
    ],
    rootfs = ":install_node_rootfs",
    secret = "0123abcd0123abcd0123abcd0123abcd",
    timeout_seconds = 60,
    vm = ":install_node_vm",
)
```

### Public targets

All of these are in `@rules_firecracker//firecracker`.

| Target | What it is |
| --- | --- |
| `:defs.bzl`, `:defs` | The macros. Use `:defs` (a `bzl_library`) if you generate your own docs with stardoc. |
| `:firecracker` | Firecracker v1.17.0, from the official release, checked by sha256. It's the x86_64 build, or aarch64 when you build for aarch64. |
| `:vmlinux` | The guest kernel, Linux 6.1.155. It's built from the kernel.org source with [`vmlinux-6.1.config`](firecracker/private/vmlinux-6.1.config): firecracker's CI config plus FUSE, EFI partitions, dummy and bridge interfaces, and kernel IP config. It uses the host's compiler but is cached like any other build step. The output file is `vmlinux.bin`. |
| `:busybox_static` | busybox 1.35.0, static x86_64 musl build. |
| `:k3s_binary` | k3s v1.30.4+k3s1, static. |
| `:jq` | jq 1.8.1, static. The k3s test uses it to read reports. |
| `:k3s_init` | The init script for `firecracker_k3s_test`. See [The k3s test report](#the-k3s-test-report). |
| `:k3s_cluster_init` | The init script for multi-node k3s VMs. See [k3s cluster settings](#k3s-cluster-settings). |
| `:mkinitramfs`, `:mkrootfs`, `:mkcontainerfs`, `:mkk3srootfs`, `:mksystemdrootfs`, `:mknoderootfs`, `:mknodeimage`, `:gen_test`, `:gen_k3s_test` | The tools listed below. |

### Image builder tools

These are the scripts the macros run. You can call them from your own
genrules with `$(execpath @rules_firecracker//firecracker:<tool>)`.

You can repeat any `SRC=DST` flag. `DST` is an absolute path unless the
table says otherwise. Every tool exits with code 2 if you call it wrong.

| Tool | Flags |
| --- | --- |
| `mkinitramfs` | `--out PATH --busybox PATH --init PATH [--file SRC=DST] [--exec SRC=DST]`. Works like `firecracker_initramfs`. |
| `mkrootfs` | `--out PATH --size-mb N --label STR [--file SRC=DST] [--exec SRC=DST]` |
| `mkcontainerfs` | `--out PATH --image-dir OCI_LAYOUT --busybox PATH --size-mb N --label STR [--extra-env K=V] [--extra-arg ARG]` |
| `mkk3srootfs` | `--out PATH --busybox PATH --k3s PATH --init PATH --test-binary PATH --test-binary-name NAME --scenario NAME --size-mb N --label STR [--file SRC=DST] [--exec SRC=DST] [--manifest SRC=FILENAME] [--image SRC=FILENAME]` |
| `mksystemdrootfs` | `--out --k3s --openfactoryd --rig-script --rig-unit --size-mb --label [--base-tag TAG] [--exec SRC=DST] [--file SRC=DST] [--image SRC=FILENAME]`. Builds a Debian root filesystem with systemd. Needs docker or podman, and fakeroot. |
| `mknoderootfs` | `--out --k3s --openfactoryd --service --provision-script --provision-unit --nodewatch-script --nodewatch-unit --size-mb --label [--base-tag TAG]`. Builds a Debian node root filesystem with systemd. Needs docker or podman, and fakeroot. |
| `mknodeimage` | Same flags as `mknoderootfs`. Builds a Debian node image that has its own kernel. Needs docker or podman. |
| `gen_test` | `--out PATH --runner-rloc RLOC --timeout N [--expect M] [--unexpect M]`. Writes a `firecracker_test` script. |
| `gen_k3s_test` | `--out PATH --runner-rloc RLOC --timeout N [--jq-rloc RLOC]`. Writes a `firecracker_k3s_test` script. |

`mksystemdrootfs`, `mknoderootfs` and `mknodeimage` exist for openfactory's
node images.
They bake in an `openfactoryd` binary and its systemd units, and this repo's
tests don't cover them. The comment at the top of each script lists every
flag.

## What guests print

### Console markers

Tests read the VM's serial console (`console=ttyS0`). So a guest reports
results by printing lines. With the generic macros you pick the strings.
The guests that ship with these rules print these:

| Guest | Markers |
| --- | --- |
| `firecracker_container` init | `FIRECRACKER_CONTAINER_READY`, `FIRECRACKER_CONTAINER_EXIT=<rc>` |
| `k3s_init` | `K3S_BOOTING`, `K3S_READY` or `K3S_FAILED`, `SCENARIO_BEGIN:<scenario>`, `===REPORT_BEGIN===` … `===REPORT_END===`, `SCENARIO_END:<scenario>:<rc>`, `K3S_POWEROFF` |
| `k3s_cluster_init` | `K3SC_BOOTING`, `K3SC_ROLE:<role>:<node>:<ip>`, `K3SC_AGENT_UP`, `K3SC_AGENT_EXITED`, `K3SC_CLUSTER_READY nodes=<n>` or `K3SC_CLUSTER_FAILED` |

When your guest is done, have it run `reboot -f`. That ends the VM, as long
as `reboot=k` is on the kernel command line. It's in
`DEFAULT_KERNEL_CMDLINE`.

### The k3s test report

`k3s_init` waits up to 240 seconds for the node to be ready. Then it applies
`/etc/manifests/*.yaml` and runs your test program like this:

```
/usr/local/bin/<test_binary> --scenario=/etc/manifests/<scenario>.yaml \
    --report-json=/tmp/report.json \
    --kubeconfig=/etc/rancher/k3s/k3s.yaml --namespace=default
```

Afterwards it prints `/tmp/report.json` between `===REPORT_BEGIN===` and
`===REPORT_END===`. The report has to be a JSON object like this:

```json
{
  "scenario": "k3s_smoke",
  "pass_conditions": [
    {"id": "boot.k3s-ready", "label": "k3s-ready", "passed": true},
    {"id": "x.y", "label": "x", "passed": false, "error": "why it failed"}
  ]
}
```

The test passes only if `pass_conditions` has at least one entry and every
entry has `"passed": true`. That has to be the JSON boolean, not a string.
Each failing entry is printed as `id`, `label` and `error`, separated by tabs.

Some failures get a report written for you:

- If your program writes no report, `k3s_init` writes one with a failing
  `harness.exit` entry.
- If k3s never becomes ready, it writes one with a failing `boot.k3s-ready`
  entry.

You'll find the report and the console log as `report.json` and
`serial.log` in `bazel-testlogs/<package>/<name>/test.outputs/`. If
`$SCENARIO_REPORT_PATH` is set and writable, the report is copied there
too.

k3s runs with `--disable=traefik,servicelb,metrics-server`, and flannel uses
`host-gw` on a dummy interface (`10.42.0.10`). The VM has no network
access, so every image it needs has to come in through `extra_images`.

### Cluster node specs

Each entry in `nodes` has four comma-separated fields, `"IDX,IP,MAC,EXTRA"`:

- `IDX` is a small number that names the node. Its console log is
  `vm<IDX>.log` and its TAP device is `fct<pid>_<IDX>`. The renumber test
  uses it to give each node its disk back.
- `IP` is the guest's IPv4 address. It has to be inside `subnet_gw`'s
  network.
- `MAC` is the guest's MAC address, like `06:00:AC:10:00:11`.
- `EXTRA` is more kernel command line arguments, separated by spaces. It
  can't contain commas.

Each node's kernel command line gets `ip=<IP>::<GW>:<MASK>::eth0:off
<EXTRA>`. The kernel sets up `eth0` before init starts.

### k3s cluster settings

`k3s_cluster_init` reads these settings from a node's `EXTRA` field:

| Setting | Default | Meaning |
| --- | --- | --- |
| `ofd.role=server\|agent` | `server` | The node's k3s role. |
| `ofd.node=<name>` | `node0` | Node name and hostname. |
| `ofd.token=<token>` | `ofdclustertoken` | The token every node shares. |
| `ofd.server=<ip>` | none | For agents: the server to join, at `https://<ip>:6443`. |
| `ofd.expect=<n>` | `1` | For the server: how many ready nodes to wait for before it prints `K3SC_CLUSTER_READY`. |

This 3-node cluster is from [`tests/cluster`](tests/cluster/BUILD.bazel):

```starlark
firecracker_cluster_test(
    name = "k3s_cluster_test",
    expect_marker = "K3SC_CLUSTER_READY nodes=3",
    leader_idx = "0",
    nodes = [
        "0,10.211.57.10,06:00:AC:10:39:10,ofd.role=server ofd.node=server0 ofd.token=fctesttoken ofd.expect=3",
        "1,10.211.57.11,06:00:AC:10:39:11,ofd.role=agent ofd.node=agent1 ofd.token=fctesttoken ofd.server=10.211.57.10",
        "2,10.211.57.12,06:00:AC:10:39:12,ofd.role=agent ofd.node=agent2 ofd.token=fctesttoken ofd.server=10.211.57.10",
    ],
    subnet_gw = "10.211.57.1/24",
    timeout_seconds = 360,
    vm = ":k3s_cluster_vm",
)
```

## Running in GitHub Actions

GitHub's hosted x64 Ubuntu runners support KVM. You just have to turn it on.
Here's a workflow you can copy:

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Host packages (kernel build + ext4 images)
        run: |
          sudo apt-get update -qq
          sudo apt-get install -y -qq build-essential flex bison bc libelf-dev libssl-dev e2fsprogs
      - name: Enable KVM
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' \
            | sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules
          sudo udevadm trigger --name-match=kvm
      - name: Allow bazel's sandbox on Ubuntu 24.04
        run: sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
      - uses: bazel-contrib/setup-bazel@8cb04a772ab4c1eb984e9c1b493a182e96c5e425 # 0.19.0
        with:
          bazelisk-cache: true
          repository-cache: true
          disk-cache: ${{ github.workflow }}   # keeps the ~10 min kernel build
      - run: bazel test --config=kvm //...
```

The cluster tests are tagged `manual`, so you have to name them. They need
passwordless sudo, which hosted runners have. The install test also needs
the `gdisk`, `dosfstools` and `exfatprogs` packages.

Run them with `--test_env=FC_NO_SKIP=1`. Then a missing prerequisite fails
the build instead of quietly skipping.

This repo's own [workflow](.github/workflows/ci.yml) builds the kernel once
in its own job and shares it with the other jobs through `actions/cache`.

## Host requirements

To run a VM, the host only needs x86_64 Linux and a `/dev/kvm` your user can
read and write. firecracker, busybox, k3s and jq are all pinned downloads.

Other things need more:

- **Building the kernel** (`//firecracker:vmlinux`) uses the host's
  compiler. You need `gcc`, `make`, `bc`, `flex`, `bison`, `perl`, and the
  `libelf` and `libssl` headers. On Debian or Ubuntu, install
  `build-essential flex bison bc libelf-dev libssl-dev`. It takes about 3
  minutes on 32 cores, or 10 to 15 minutes on a 4-core runner. Bazel caches
  it like any other step, so a disk or remote cache saves you from doing it
  again.
- **The scripts** need bash, coreutils, util-linux (for `setsid`), and GNU
  `tar`, `sed`, `awk` and `grep`.
- **Every ext4 image** (`firecracker_rootfs`, `firecracker_container`,
  `firecracker_k3s_test`) needs e2fsprogs 1.43 or newer, for `mkfs.ext4 -d`.
- **`firecracker_container`** needs python3 to read the image config, and
  `zstd` if a layer is zstd-compressed.
- **The cluster tests** need passwordless `sudo` for `ip` and `iptables`.
  The install test also needs `losetup`, `sgdisk` (from gdisk), `mkfs.fat`
  (from dosfstools) and `mkfs.exfat` (from exfatprogs).
- **`mksystemdrootfs`, `mknoderootfs` and `mknodeimage`** need docker or
  podman, and fakeroot.

On Ubuntu 24.04, Bazel's sandbox doesn't work until you run
`sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0`.

## Working on this repo

```
firecracker/defs.bzl      the public macros (load this one)
firecracker/BUILD.bazel   the public targets
firecracker/private/      everything else: macros.bzl, scripts, templates, kernel config
examples/                 small examples, which are also tests
tests/unit/               tests for the tools and scripts; no KVM needed
tests/vm/                 single-VM boots, timeouts and failure cases
tests/container/          firecracker_container with a rules_oci image
tests/k3s/                firecracker_k3s_test options and a failing report
tests/cluster/            multi-VM tests (test_suite :cluster)
e2e/smoke/                a separate workspace that uses this module as a dependency
docs/                     generated API docs
.bcr/                     templates for publishing to the Bazel Central Registry
```

Common commands:

```sh
bazel test //tests/unit/... //docs/...          # no KVM needed
bazel test --config=kvm //...                   # every test that isn't manual
bazel test --config=ci //tests/cluster:cluster  # multi-VM tests; needs sudo
(cd e2e/smoke && bazel test --config=kvm //...)
bazel run //docs:update                         # run after you change a docstring
```

## License

[GPL-3.0](LICENSE).
