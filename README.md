# rules_firecracker

Bazel rules for building [Firecracker](https://firecracker-microvm.github.io/)
microVM images and running tests inside them: initramfs and ext4 rootfs
builders, a pinned 6.1 guest kernel, a pinned firecracker release, a runnable
`firecracker_microvm`, and test macros from single-VM console checks up to
multi-node k3s clusters booted on a host bridge.

Nothing is taken from the host `PATH` to run a VM: the firecracker binary is
an official upstream release (v1.17.0) fetched by sha256 and resolved through
runfiles. See [Host requirements](#host-requirements) for what the host still
provides.

- [Setup](#setup)
- [Quick start](#quick-start)
- [API reference](#api-reference): [macros](#macros), [public targets](#public-targets), [tools](#image-builder-tools)
- [Guest-side contracts](#guest-side-contracts)
- [Running in GitHub Actions](#running-in-github-actions)
- [Host requirements](#host-requirements)
- [Repository layout and development](#repository-layout-and-development)

Generated reference for every macro: [docs/defs.md](docs/defs.md).

## Setup

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
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_test")
```

Copy the `kvm` config into your `.bazelrc`; every VM test is tagged
`requires-kvm` and needs `/dev/kvm` mounted into the sandbox:

```
build:kvm --sandbox_add_mount_pair=/dev/kvm
test:kvm --sandbox_add_mount_pair=/dev/kvm
```

Then `bazel test --config=kvm //...`. On a host without KVM, skip VM tests
with `--test_tag_filters=-requires-kvm`. The invoking user needs read/write
access to `/dev/kvm` (usually membership in the `kvm` group).

## Quick start

From [`examples/hello`](examples/hello/BUILD.bazel):

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

```sh
#!/bin/sh
# hello_init.sh — /init (PID 1)
mount -t proc proc /proc
echo "HELLO_FROM_INITRD"
echo "GREETING=$(cat /etc/greeting)"
reboot -f   # with reboot=k (default cmdline) this makes firecracker exit
```

`bazel run //examples/hello:hello_vm` boots the same VM with its console on
your terminal.

## API reference

Everything is loaded from `@rules_firecracker//firecracker:defs.bzl`. The
default labels below are written relative to `@rules_firecracker`.

### Macros

| Macro | Creates |
| --- | --- |
| [`firecracker_initramfs`](#firecracker_initramfs) | `<name>.cpio.gz` initramfs |
| [`firecracker_rootfs`](#firecracker_rootfs) | `<name>.ext4` disk image |
| [`firecracker_microvm`](#firecracker_microvm) | runnable `sh_binary` that boots a VM |
| [`firecracker_test`](#firecracker_test) | `sh_test` asserting on the serial console |
| [`firecracker_container`](#firecracker_container) | microvm that runs one OCI image as the guest |
| [`firecracker_k3s_test`](#firecracker_k3s_test) | `sh_test`: single-node k3s + guest test binary |
| [`firecracker_cluster_test`](#firecracker_cluster_test) | `sh_test`: N VMs on a host bridge |
| [`firecracker_renumber_test`](#firecracker_renumber_test) | `sh_test`: cluster rebooted onto a new subnet with persistent disks |
| [`firecracker_install_cluster_test`](#firecracker_install_cluster_test) | `sh_test`: install to GPT disks, then boot them |

`DEFAULT_KERNEL_CMDLINE` is also exported:
`console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on`. `reboot=k`
makes a guest `reboot -f` end the firecracker process, which is how guests
signal "done" (a `poweroff` only halts the vCPU until the host kills it).

Every macro forwards unknown keyword arguments (`**kwargs`) to its main
underlying rule (`genrule`, `sh_binary` or `sh_test`).

#### firecracker_initramfs

Packs a gzip-compressed newc cpio. The archive holds a static busybox at
`/bin/busybox` with every applet symlinked into `/bin` (and `init mount umount
sh` into `/sbin`), your `init` at `/init`, an `/etc/fstab`, and empty
`/dev /proc /sys /tmp /run`. Packing uses busybox's own `cpio` and `gzip`.
Every ELF in `execs` (and `busybox`) is checked for a `PT_INTERP` header: a
dynamically-linked binary fails the build, since the initramfs has no libc.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | Output is `<name>.cpio.gz`. |
| `init` | label | required | Script or static binary installed at `/init` (0755). |
| `files` | dict label → abs path | `{}` | Files installed 0644. |
| `execs` | dict label → abs path | `{}` | Files installed 0755; ELFs must be static. |
| `busybox` | label | `//firecracker:busybox_static` | Static busybox. |

Tags: none added. Example: [Quick start](#quick-start).

#### firecracker_rootfs

Builds an ext4 image with `mkfs.ext4 -d` (no root, mount or loop device). The
image holds only what you list — no mount points — so to boot it as root,
supply a PID 1, pass `rw init=/sbin/init` and have init create `/proc` etc.
Also usable as a data disk (`extra_drive`). The genrule is `local` (the
sparse image would be stored densely by caches).

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | Output is `<name>.ext4`. |
| `size_mb` | int | required | Image size in MiB (sparse). |
| `label` | string | required | ext4 volume label (max 16 chars). |
| `files` | dict label → abs path | `{}` | Files installed 0644. |
| `execs` | dict label → abs path | `{}` | Files installed 0755. |

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

A runnable `sh_binary` (always tagged `manual`). At run time it resolves the
kernel, boot image and firecracker binary through runfiles, writes a
`vm.json` into a fresh temp dir and runs
`firecracker --no-api --config-file vm.json` with the serial console on
stdout. Exactly one of `initrd` / `rootfs` must be set.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The runnable target. |
| `kernel` | label | `//firecracker:vmlinux` | Uncompressed kernel ELF. |
| `initrd` | label | `None` | cpio.gz initramfs (initrd mode). |
| `rootfs` | label | `None` | ext4 root image, booted as `/dev/vda` with `root=/dev/vda` appended; copied first, so the VM may write it. |
| `extra_drive` | label | `None` | Extra writable virtio-block disk, copied first; `/dev/vda` in initrd mode, `/dev/vdb` in rootfs mode. |
| `kernel_cmdline` | string | `DEFAULT_KERNEL_CMDLINE` | Kernel boot args. |
| `vcpus` | int | `1` | vCPU count. |
| `mem_mib` | int | `256` | Guest memory (MiB). |
| `firecracker` | label | `//firecracker:firecracker` | **New.** A single executable file used as the VMM. Point it at your own build to override the pinned release. |
| `visibility`, `tags` | | | Forwarded; `manual` is always added. |

Runtime environment variables:

| Variable | Effect |
| --- | --- |
| `FC_TIMEOUT=<s>` | SIGKILL the VM after `<s>` seconds and exit 0. Non-timeout firecracker exit codes propagate. |
| `FC_KEEP_WORK=1` | Keep the temp dir (prints its path) to inspect e.g. `extra.img` afterwards. |
| `FC_TAP`, `FC_GUEST_MAC` | Attach a virtio-net NIC on host TAP `FC_TAP` (MAC default `06:00:AC:10:00:02`). |
| `FC_CMDLINE_EXTRA` | Appended to the kernel cmdline (e.g. `ip=<ip>::<gw>:<mask>::eth0:off`). |
| `FC_PERSIST_DISK=<path>` | Rootfs mode: attach this host file in place (not copied) as the last drive: `/dev/vdb`, or `/dev/vdc` after an `extra_drive`. |
| `FC_BOOT_DISK=<path>`, `FC_ROOT_PART` | Boot from a partitioned disk instead; root defaults to `/dev/vda2`. |
| `FC_FIRECRACKER=<path>` | Use this firecracker binary instead of the runfiles one (debugging). |

Example: [Quick start](#quick-start). The `firecracker` override is exercised
by [`tests/unit`](tests/unit/BUILD.bazel) with a fake VMM:

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

An `sh_test` that runs a microvm with `FC_TIMEOUT=timeout_seconds`, streams
the console into the test log, kills the VM as soon as every expected marker
has appeared, and otherwise waits for it to exit or time out (a timeout kill
is not by itself a failure). It then fails if any `expect_markers` string is
missing or any `unexpected_markers` string is present (fixed-string match).
Tags added: `requires-kvm`, `no-cache`.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The test. |
| `microvm` | label | required | A `firecracker_microvm` / `firecracker_container`. |
| `expect_markers` | string list | `[]` | Must all appear on the console. |
| `unexpected_markers` | string list | `[]` | Must not appear. |
| `timeout_seconds` | int | `30` | Hard cap on VM wall time. |
| `size` | string | `"medium"` | `sh_test` size. |
| `visibility`, `tags` | | | Forwarded (plus the tags above). |

Example: [Quick start](#quick-start).

#### firecracker_container

Boots one OCI image as the whole guest. Layers are flattened (honoring `.wh.`
whiteouts and opaque dirs) into an ext4 rootfs; a static busybox goes to
`/sbin/busybox` and a generated `/sbin/init` mounts `/proc /sys /dev /tmp
/run`, exports the image `Env` then `extra_env`, `cd`s to `WorkingDir`,
prints `FIRECRACKER_CONTAINER_READY`, runs `Entrypoint + Cmd + extra_args`,
prints `FIRECRACKER_CONTAINER_EXIT=<rc>` and reboots (so firecracker exits).
Expands to `firecracker_microvm(name = name)` plus a `local` genrule
`_<name>__rootfs`.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The runnable microvm. |
| `image` | label | required | `oci_image` or any OCI layout directory. |
| `size_mb` | int | `512` | Rootfs size (MiB); must exceed the flattened image. |
| `kernel` | label | `//firecracker:vmlinux` | Guest kernel. |
| `extra_env` | dict string → string | `{}` | Exported after the image `Env` (overrides). |
| `extra_args` | string list | `[]` | Appended after `Entrypoint + Cmd`. |
| `kernel_cmdline` | string | `DEFAULT_KERNEL_CMDLINE + " init=/sbin/init"` | Boot args. |
| `vcpus` | int | `1` | vCPUs. |
| `mem_mib` | int | `512` | Guest memory. |
| `busybox` | label | `//firecracker:busybox_static` | Copied to `/sbin/busybox`. |
| `firecracker` | label | `//firecracker:firecracker` | **New.** VMM binary, as for `firecracker_microvm`. |
| `visibility`, `tags` | | | Forwarded to the microvm. |

From [`tests/container`](tests/container/BUILD.bazel) (rules_oci):

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

Boots a single-node k3s server in a VM and runs your statically-linked guest
test binary against it; see the [report contract](#k3s-test-report). The
rootfs holds busybox, k3s at `/usr/local/bin/k3s` (with `kubectl`, `crictl`,
`ctr` symlinks), the test binary at `/usr/local/bin/<test_binary's name>`
and the PID 1 `init`. Creates `_<name>__rootfs` (local genrule),
`_<name>__microvm` and the test. Tags added: `requires-kvm`, `no-cache`.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The test. |
| `test_binary` | label | required | Static guest test binary (cgo-free `go_binary`, etc.). |
| `scenario` | string | required | Written to `/etc/scenario`; passed as `--scenario=/etc/manifests/<scenario>.yaml`. |
| `extra_manifests` | dict label → basename | `{}` | Copied to `/etc/manifests/`, `kubectl apply`'d once k3s is Ready. |
| `extra_images` | dict label → basename | `{}` | Image tarballs copied to `/etc/images/`, auto-imported into k3s' containerd. |
| `extra_files` | dict label → abs path | `{}` | Files installed 0644. |
| `extra_execs` | dict label → abs path | `{}` | Files installed 0755. |
| `timeout_seconds` | int | `300` | Hard cap on VM wall time. |
| `vcpus` | int | `2` | vCPUs. |
| `mem_mib` | int | `2048` | Guest memory. |
| `size_mb` | int | `2048` | Rootfs size. |
| `kernel` | label | `//firecracker:vmlinux` | Guest kernel. |
| `kernel_cmdline` | string | `DEFAULT_KERNEL_CMDLINE` | Boot args. |
| `busybox` | label | `//firecracker:busybox_static` | Static busybox. |
| `k3s` | label | `//firecracker:k3s_binary` | Static k3s. |
| `init` | label | `//firecracker:k3s_init` | `/sbin/init`. |
| `firecracker` | label | `//firecracker:firecracker` | **New.** VMM binary. |
| `size` | string | `"enormous"` | `sh_test` size. |
| `visibility`, `tags` | | | Forwarded (plus the tags above). |

From [`examples/k3s_smoke`](examples/k3s_smoke/BUILD.bazel); see
[`tests/k3s`](tests/k3s/BUILD.bazel) for every `extra_*` attribute in use:

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

Creates a Linux bridge (host side `subnet_gw`) and a TAP per node, boots every
node of `vm` concurrently with `ip=<IP>::<GW>:<MASK>::eth0:off <EXTRA>` on its
cmdline, waits for all to exit (or `timeout_seconds`), tears the network
down, and passes iff `expect_marker` is in any node's console log. Runs
`local` (unsandboxed: host netns, `sudo -n ip ...`, iptables `FORWARD` accept
for the bridge, `/dev/kvm`). Tags added: `requires-kvm no-cache local
no-sandbox manual` — so `//...` skips it; list it in a `test_suite` or name
it explicitly. Without `/dev/kvm` or passwordless sudo it SKIPs (exit 0),
unless `FC_NO_SKIP=1` is in the test env, which turns the SKIP into a failure.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The test. |
| `vm` | label | required | `firecracker_microvm` every node boots. |
| `nodes` | string list | required | [Node specs](#cluster-node-specs). |
| `expect_marker` | string | required | Must appear in some node's log. |
| `leader_idx` | string | required | Node whose log tail is printed. |
| `subnet_gw` | string | `"10.211.55.1/24"` | Bridge address (CIDR) = guests' gateway. |
| `timeout_seconds` | int | `360` | Per-VM cap. |
| `size` | string | `"enormous"` | `sh_test` size. |
| `visibility`, `tags` | | | Forwarded (plus the tags above). |

From [`tests/cluster`](tests/cluster/BUILD.bazel):

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

Two phases with the same per-node persistent disks: phase 1 boots `nodes1` on
`gw1`, each node with a 2 GiB ext4 disk at `/dev/vdb` (created once per IDX);
phase 2 boots `nodes2` (same IDXs and MACs, new IPs) on `gw2`. Passes iff
`expect_marker` appears in a phase-2 log. `vm` must be rootfs-mode. Same
tags/SKIP rules as `firecracker_cluster_test`.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The test. |
| `vm` | label | required | Rootfs-mode microvm. |
| `nodes1`, `nodes2` | string list | required | Phase 1 / 2 node specs. |
| `gw1`, `gw2` | string | required | Phase 1 / 2 bridge address (CIDR). |
| `expect_marker` | string | required | Must appear in a phase-2 log. |
| `timeout1`, `timeout2` | int | `240`, `300` | Per-VM cap per phase. |
| `size` | string | `"enormous"` | `sh_test` size. |
| `visibility`, `tags` | | | Forwarded. |

From [`tests/cluster`](tests/cluster/BUILD.bazel):

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

Phase 1, per node: a sparse 5 GiB disk attached with `sudo losetup -fP`, a
`settings.ini`

```ini
[node]
role = server
[cluster]
cluster_secret = <secret>
[install]
target_disk = /dev/loopN
wipe_confirm = yes-i-am-sure
```

and `sudo <installer> --settings <settings.ini> --rootfs-image <rootfs>`,
which must partition the disk and put a bootable root filesystem on
partition 2. Phase 2 boots each disk (`root=/dev/vda2`) on a bridge at `gw`
and passes iff `expect_marker` appears. `vm` supplies kernel, cmdline and
machine size only. `installer` may be a `go_binary` or any single-file
executable (e.g. `sh_binary`). Needs `losetup sgdisk mkfs.fat mkfs.ext4
mkfs.exfat` on the host (SKIP otherwise, failure with `FC_NO_SKIP=1`). Same
tags as `firecracker_cluster_test`.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | name | required | The test. |
| `vm` | label | required | Kernel/cmdline/size donor microvm. |
| `installer` | label | required | Installer executable. |
| `rootfs` | label | required | Root image handed to the installer. |
| `nodes` | string list | required | Node specs. |
| `expect_marker` | string | required | Must appear in a phase-2 log. |
| `gw` | string | `"10.211.55.1/24"` | Bridge address (CIDR). |
| `secret` | string | 64 hex chars | `cluster_secret` in each settings.ini. |
| `timeout_seconds` | int | `360` | Phase-2 per-VM cap. |
| `size` | string | `"enormous"` | `sh_test` size. |
| `visibility`, `tags` | | | Forwarded. |

[`tests/cluster`](tests/cluster/BUILD.bazel) drives it with a generic
`sgdisk` + `dd` installer ([`installer.sh`](tests/cluster/installer.sh)):

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

All in `@rules_firecracker//firecracker`:

| Target | What |
| --- | --- |
| `:defs.bzl`, `:defs` | The macros; `:defs` is the `bzl_library` for your own stardoc. |
| `:firecracker` | Firecracker v1.17.0 from the upstream release tarball (sha256-pinned); x86_64, or aarch64 on an aarch64 target platform. |
| `:vmlinux` | Guest kernel: Linux 6.1.155 built from the kernel.org tarball with [`vmlinux-6.1.config`](firecracker/private/vmlinux-6.1.config) (firecracker's CI config + `CONFIG_FUSE_FS=y`, `EFI_PARTITION`, `DUMMY`, `BRIDGE`, `IP_PNP`). Sandboxed, cacheable; uses the host compiler. Output `vmlinux.bin`. |
| `:busybox_static` | busybox 1.35.0 x86_64 musl, static. |
| `:k3s_binary` | k3s v1.30.4+k3s1, static. |
| `:jq` | jq 1.8.1, static (used by the k3s test launcher). |
| `:k3s_init` | Default PID 1 of `firecracker_k3s_test` ([contract](#k3s-test-report)). |
| `:k3s_cluster_init` | PID 1 for multi-node k3s nodes ([cmdline fields](#k3s-cluster-node-cmdline)). |
| `:mkinitramfs`, `:mkrootfs`, `:mkcontainerfs`, `:mkk3srootfs`, `:mksystemdrootfs`, `:mknoderootfs`, `:mknodeimage`, `:gen_test`, `:gen_k3s_test` | Tools below. |

### Image builder tools

`sh_binary` tools the macros drive; call them from your own genrules with
`$(execpath @rules_firecracker//firecracker:<tool>)`. `SRC=DST` flags are
repeatable; `DST` paths are absolute unless noted. All exit 2 on usage errors.

| Tool | Flags |
| --- | --- |
| `mkinitramfs` | `--out PATH --busybox PATH --init PATH [--file SRC=DST] [--exec SRC=DST]` — see `firecracker_initramfs`. |
| `mkrootfs` | `--out PATH --size-mb N --label STR [--file SRC=DST] [--exec SRC=DST]` |
| `mkcontainerfs` | `--out PATH --image-dir OCI_LAYOUT --busybox PATH --size-mb N --label STR [--extra-env K=V] [--extra-arg ARG]` |
| `mkk3srootfs` | `--out PATH --busybox PATH --k3s PATH --init PATH --test-binary PATH --test-binary-name NAME --scenario NAME --size-mb N --label STR [--file SRC=DST] [--exec SRC=DST] [--manifest SRC=BASENAME] [--image SRC=BASENAME]` |
| `mksystemdrootfs` | `--out --k3s --openfactoryd --rig-script --rig-unit --size-mb --label [--base-tag TAG] [--exec SRC=DST] [--file SRC=DST] [--image SRC=BASENAME]` — Debian+systemd rootfs for systemd-managed rigs. Needs docker/podman + fakeroot. |
| `mknoderootfs` | `--out --k3s --openfactoryd --service --provision-script --provision-unit --nodewatch-script --nodewatch-unit --size-mb --label [--base-tag TAG]` — production Debian+systemd node rootfs. Needs docker/podman + fakeroot. |
| `mknodeimage` | same flags as `mknoderootfs` — self-contained Debian node image with its own kernel. Needs docker/podman. |
| `gen_test` | `--out PATH --runner-rloc RLOC --timeout N [--expect M] [--unexpect M]` — emits a `firecracker_test` script. |
| `gen_k3s_test` | `--out PATH --runner-rloc RLOC --timeout N [--jq-rloc RLOC]` — emits a `firecracker_k3s_test` script. |

`mksystemdrootfs`, `mknoderootfs` and `mknodeimage` are specific to
openfactory node images (they bake in an
`openfactoryd` binary and its units) and are not exercised by this repo's
tests. Each script's header documents its flags in full.

## Guest-side contracts

### Console markers

Tests assert on the serial console (`console=ttyS0`), so guests report by
printing lines. The generic macros look for whatever strings you choose; the
bundled guests print:

| Source | Markers |
| --- | --- |
| `firecracker_container` init | `FIRECRACKER_CONTAINER_READY`, `FIRECRACKER_CONTAINER_EXIT=<rc>` |
| `k3s_init` | `K3S_BOOTING`, `K3S_READY` or `K3S_FAILED`, `SCENARIO_BEGIN:<scenario>`, `===REPORT_BEGIN===` … `===REPORT_END===`, `SCENARIO_END:<scenario>:<rc>`, `K3S_POWEROFF` |
| `k3s_cluster_init` | `K3SC_BOOTING`, `K3SC_ROLE:<role>:<node>:<ip>`, `K3SC_AGENT_UP`, `K3SC_AGENT_EXITED`, `K3SC_CLUSTER_READY nodes=<n>` or `K3SC_CLUSTER_FAILED` |

End a guest with `reboot -f` so firecracker exits (needs `reboot=k`, part of
`DEFAULT_KERNEL_CMDLINE`).

### k3s test report

`k3s_init` waits for the node to be Ready (up to 240 s), applies
`/etc/manifests/*.yaml`, then runs

```
/usr/local/bin/<test_binary> --scenario=/etc/manifests/<scenario>.yaml \
    --report-json=/tmp/report.json \
    --kubeconfig=/etc/rancher/k3s/k3s.yaml --namespace=default
```

and prints `/tmp/report.json` between `===REPORT_BEGIN===` and
`===REPORT_END===`. The report must be a JSON object:

```json
{
  "scenario": "k3s_smoke",
  "pass_conditions": [
    {"id": "boot.k3s-ready", "label": "k3s-ready", "passed": true},
    {"id": "x.y", "label": "x", "passed": false, "error": "why it failed"}
  ]
}
```

The test passes iff `pass_conditions` is a non-empty array and every entry
has `"passed": true` (boolean). Failing entries are printed as
`id<TAB>label<TAB>error`. If the binary writes no report, `k3s_init`
synthesizes one with a failing `harness.exit` entry; if k3s never gets Ready,
one with a failing `boot.k3s-ready`. The report and console log are saved as
`report.json` and `serial.log` in the test's undeclared outputs
(`bazel-testlogs/<pkg>/<name>/test.outputs/`), and the report is also copied
to `$SCENARIO_REPORT_PATH` when that env var is set and writable.

k3s runs with `--disable=traefik,servicelb,metrics-server`, flannel
`host-gw` on a dummy interface (`10.42.0.10`), and no network access, so
images must come from `extra_images`.

### Cluster node specs

`nodes` entries are `"IDX,IP,MAC,EXTRA"`:

- `IDX` — small integer; console log `vm<IDX>.log`, TAP `fct<pid>_<IDX>`.
  Renumber phases match nodes (and their persistent disks) by IDX.
- `IP` — guest IPv4 address inside `subnet_gw`'s network.
- `MAC` — guest MAC, e.g. `06:00:AC:10:00:11`.
- `EXTRA` — extra kernel cmdline arguments, space-separated (no commas).

Each node's cmdline gets `ip=<IP>::<GW>:<MASK>::eth0:off <EXTRA>`; the kernel
(`CONFIG_IP_PNP`) configures `eth0` before init runs.

### k3s cluster node cmdline

`k3s_cluster_init` reads these `EXTRA` fields:

| Field | Default | Meaning |
| --- | --- | --- |
| `ofd.role=server\|agent` | `server` | k3s role. |
| `ofd.node=<name>` | `node0` | Node name / hostname. |
| `ofd.token=<token>` | `ofdclustertoken` | Shared cluster token. |
| `ofd.server=<ip>` | — | Agents: server to join (`https://<ip>:6443`). |
| `ofd.expect=<n>` | `1` | Server: Ready nodes to wait for before `K3SC_CLUSTER_READY`. |

From [`tests/cluster`](tests/cluster/BUILD.bazel) (a 3-node cluster):

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

GitHub-hosted x64 Ubuntu runners support KVM. A consumer workflow:

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
          disk-cache: ${{ github.workflow }}   # caches the ~10 min kernel build
      - run: bazel test --config=kvm //...
```

Cluster tests (tagged `manual`) additionally need passwordless sudo — which
hosted runners have — and `gdisk dosfstools exfatprogs` for the install rig;
run them with `--test_env=FC_NO_SKIP=1` so a broken prerequisite fails
instead of skipping. This repo's own [workflow](.github/workflows/ci.yml)
builds the kernel once in a dedicated job and shares it via
`actions/cache`.

## Host requirements

- x86_64 Linux with `/dev/kvm` readable/writable by the build user. Nothing
  else is needed to *run* a VM: firecracker, busybox, k3s and jq are pinned
  downloads.
- `//firecracker:vmlinux` compiles the kernel with the host toolchain:
  `gcc make bc flex bison perl` and the `libelf-dev libssl-dev` headers
  (Debian: `build-essential flex bison bc libelf-dev libssl-dev`). ~3 min
  on 32 cores, ~10-15 min on a 4-core runner; it is a normal (non-`local`)
  action, so a disk/remote cache keeps it.
- bash, coreutils, util-linux (`setsid`), GNU `tar`/`sed`/`awk`/`grep`.
- e2fsprogs >= 1.43 (`mkfs.ext4 -d`) for every ext4 image (`firecracker_rootfs`,
  `firecracker_container`, `firecracker_k3s_test`).
- `firecracker_container`: python3 (image config parsing), and `zstd` for
  zstd-compressed layers.
- Multi-VM tests: passwordless `sudo` for `ip` (bridge/TAP) and `iptables`;
  the install rig also `losetup`, `sgdisk` (gdisk), `mkfs.fat` (dosfstools),
  `mkfs.exfat` (exfatprogs).
- `mksystemdrootfs`/`mknoderootfs`/`mknodeimage`: docker or podman, fakeroot.

On Ubuntu 24.04, bazel's sandbox needs
`sysctl kernel.apparmor_restrict_unprivileged_userns=0`.

## Repository layout and development

```
firecracker/defs.bzl      public macros (load this)
firecracker/BUILD.bazel   public targets
firecracker/private/      implementation: macros.bzl, scripts, templates, kernel config
examples/                 small usage examples (tested)
tests/unit/               builders, generators, launcher — no KVM needed
tests/vm/                 single-VM boots, timing and failure paths
tests/container/          firecracker_container with a rules_oci image
tests/k3s/                firecracker_k3s_test extras + failing-report path
tests/cluster/            multi-VM rigs (test_suite :cluster)
e2e/smoke/                separate workspace consuming the module externally
docs/                     stardoc output (bazel run //docs:update)
.bcr/                     Bazel Central Registry publishing templates
```

```sh
bazel test //tests/unit/... //docs/...          # no KVM
bazel test --config=kvm //...                   # all non-manual tests
bazel test --config=ci //tests/cluster:cluster  # multi-VM (sudo)
(cd e2e/smoke && bazel test --config=kvm //...)
bazel run //docs:update                         # after changing a docstring
```

## License

[GPL-3.0](LICENSE).
