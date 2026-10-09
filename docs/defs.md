<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API of rules_firecracker: build and test Firecracker microVMs.

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

<a id="firecracker_cluster_test"></a>

## firecracker_cluster_test

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_cluster_test")

firecracker_cluster_test(<a href="#firecracker_cluster_test-name">name</a>, <a href="#firecracker_cluster_test-vm">vm</a>, <a href="#firecracker_cluster_test-nodes">nodes</a>, <a href="#firecracker_cluster_test-expect_marker">expect_marker</a>, <a href="#firecracker_cluster_test-leader_idx">leader_idx</a>, <a href="#firecracker_cluster_test-subnet_gw">subnet_gw</a>, <a href="#firecracker_cluster_test-timeout_seconds">timeout_seconds</a>,
                         <a href="#firecracker_cluster_test-size">size</a>, <a href="#firecracker_cluster_test-visibility">visibility</a>, <a href="#firecracker_cluster_test-tags">tags</a>, <a href="#firecracker_cluster_test-kwargs">**kwargs</a>)
</pre>

Boot N copies of a microvm on a shared host bridge; assert a console marker.

The test creates a Linux bridge (`subnet_gw` on the host side) and one
TAP per node owned by the invoking user (via `sudo -n ip ...`), boots
every node concurrently with `FC_TAP`/`FC_GUEST_MAC` and
`FC_CMDLINE_EXTRA="ip=<IP>::<GW>:<MASK>::eth0:off <EXTRA>"`, waits for
all VMs to exit (or `timeout_seconds`), tears the network down, and
passes iff `expect_marker` appears in ANY node's console log.

Each `nodes` entry is `"IDX,IP,MAC,EXTRA"`: a small integer index (TAP
`fct<pid>_<IDX>`, console log `vm<IDX>.log`), the guest IPv4 address,
the guest MAC, and extra kernel cmdline arguments (may contain spaces,
not commas). Give concurrently-running cluster tests distinct subnets.

The test is `local` (unsandboxed: host network namespace, sudo,
/dev/kvm) and tagged `requires-kvm no-cache local no-sandbox manual`;
it SKIPs (exits 0) without /dev/kvm or passwordless sudo unless
`FC_NO_SKIP=1` is in the test environment, in which case it fails.

Example:

```starlark
firecracker_cluster_test(
    name = "nettest_cluster_test",
    vm = ":nettest_vm",
    nodes = [
        "1,10.211.56.11,06:00:AC:10:38:11,ofd.peer=10.211.56.12",
        "2,10.211.56.12,06:00:AC:10:38:12,ofd.peer=10.211.56.11",
    ],
    subnet_gw = "10.211.56.1/24",
    expect_marker = "NETOK 10.211.56.11->10.211.56.12",
    leader_idx = "1",
    timeout_seconds = 60,
)
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="firecracker_cluster_test-name"></a>name |  target name of the `sh_test`.   |  none |
| <a id="firecracker_cluster_test-vm"></a>vm |  label of the `firecracker_microvm` every node boots.   |  none |
| <a id="firecracker_cluster_test-nodes"></a>nodes |  list of `"IDX,IP,MAC,EXTRA_CMDLINE"` node specs.   |  none |
| <a id="firecracker_cluster_test-expect_marker"></a>expect_marker |  string that must appear in some node's console log.   |  none |
| <a id="firecracker_cluster_test-leader_idx"></a>leader_idx |  IDX of the node whose log tail is printed for diagnostics.   |  none |
| <a id="firecracker_cluster_test-subnet_gw"></a>subnet_gw |  host bridge address in CIDR form; also the guests' gateway.   |  `"10.211.55.1/24"` |
| <a id="firecracker_cluster_test-timeout_seconds"></a>timeout_seconds |  per-VM hard cap in seconds.   |  `360` |
| <a id="firecracker_cluster_test-size"></a>size |  `sh_test` size.   |  `"enormous"` |
| <a id="firecracker_cluster_test-visibility"></a>visibility |  visibility of the `sh_test`.   |  `None` |
| <a id="firecracker_cluster_test-tags"></a>tags |  extra tags (see above for the ones always added).   |  `None` |
| <a id="firecracker_cluster_test-kwargs"></a>kwargs |  forwarded to the `sh_test`.   |  none |


<a id="firecracker_container"></a>

## firecracker_container

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_container")

firecracker_container(<a href="#firecracker_container-name">name</a>, <a href="#firecracker_container-image">image</a>, <a href="#firecracker_container-size_mb">size_mb</a>, <a href="#firecracker_container-kernel">kernel</a>, <a href="#firecracker_container-extra_env">extra_env</a>, <a href="#firecracker_container-extra_args">extra_args</a>, <a href="#firecracker_container-kernel_cmdline">kernel_cmdline</a>, <a href="#firecracker_container-vcpus">vcpus</a>,
                      <a href="#firecracker_container-mem_mib">mem_mib</a>, <a href="#firecracker_container-busybox">busybox</a>, <a href="#firecracker_container-firecracker">firecracker</a>, <a href="#firecracker_container-visibility">visibility</a>, <a href="#firecracker_container-tags">tags</a>, <a href="#firecracker_container-kwargs">**kwargs</a>)
</pre>

Boot a single OCI image as the whole guest: a runnable microvm.

The image's layers are flattened (honoring `.wh.` whiteouts and opaque
dirs) into an ext4 rootfs. A static busybox is added at `/sbin/busybox`
and a generated `/sbin/init` mounts `/proc /sys /dev /tmp /run`, exports
the image `Env` then `extra_env`, `cd`s to `WorkingDir`, prints
`FIRECRACKER_CONTAINER_READY`, runs `Entrypoint + Cmd + extra_args` as a
child, prints `FIRECRACKER_CONTAINER_EXIT=<rc>` and reboots the guest,
which (with `reboot=k`, part of the default cmdline) makes firecracker exit.
Any `/sbin/init` in the image is replaced.

Expands to `firecracker_microvm(name = name, ...)` plus a `local`
rootfs genrule `_<name>__rootfs`. Host tools: e2fsprogs, python3, tar
(and zstd for zstd layers).

Example (with rules_oci):

```starlark
oci_image(
    name = "image",
    architecture = "amd64",
    os = "linux",
    tars = [":layer1", ":layer2"],
    entrypoint = ["/sbin/busybox", "sh", "/app/run.sh"],
    cmd = ["from-cmd"],
    env = {"GREETING": "hello-from-image-env"},
    workdir = "/app",
)

firecracker_container(
    name = "container_vm",
    image = ":image",
    size_mb = 32,
    mem_mib = 128,
    extra_env = {"EXTRA_ENV": "set-by-macro"},
    extra_args = ["extra arg"],
)

firecracker_test(
    name = "container_test",
    microvm = ":container_vm",
    expect_markers = [
        "FIRECRACKER_CONTAINER_READY",
        "FIRECRACKER_CONTAINER_EXIT=7",  # run.sh exits 7
    ],
)
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="firecracker_container-name"></a>name |  target name of the runnable microvm.   |  none |
| <a id="firecracker_container-image"></a>image |  label of an `oci_image` or any target producing an OCI image layout directory (`index.json` + `blobs/sha256/...`).   |  none |
| <a id="firecracker_container-size_mb"></a>size_mb |  rootfs size in MiB; must exceed the flattened image.   |  `512` |
| <a id="firecracker_container-kernel"></a>kernel |  guest kernel. Default `@rules_firecracker//firecracker:vmlinux`.   |  `"@@//firecracker:vmlinux"` |
| <a id="firecracker_container-extra_env"></a>extra_env |  dict `{KEY: VALUE}` exported after the image `Env` (overrides same-named keys).   |  `{}` |
| <a id="firecracker_container-extra_args"></a>extra_args |  list of arguments appended after `Entrypoint + Cmd`.   |  `[]` |
| <a id="firecracker_container-kernel_cmdline"></a>kernel_cmdline |  kernel boot args; includes `init=/sbin/init` so the generated init wins over anything the image ships.   |  `"console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on init=/sbin/init"` |
| <a id="firecracker_container-vcpus"></a>vcpus |  number of vCPUs.   |  `1` |
| <a id="firecracker_container-mem_mib"></a>mem_mib |  guest memory in MiB.   |  `512` |
| <a id="firecracker_container-busybox"></a>busybox |  static busybox copied to `/sbin/busybox`.   |  `"@@//firecracker:busybox_static"` |
| <a id="firecracker_container-firecracker"></a>firecracker |  firecracker VMM binary; see `firecracker_microvm`.   |  `"@@//firecracker:firecracker"` |
| <a id="firecracker_container-visibility"></a>visibility |  visibility of the microvm.   |  `None` |
| <a id="firecracker_container-tags"></a>tags |  extra tags for the microvm (`manual` is always added).   |  `None` |
| <a id="firecracker_container-kwargs"></a>kwargs |  forwarded to `firecracker_microvm`.   |  none |


<a id="firecracker_initramfs"></a>

## firecracker_initramfs

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_initramfs")

firecracker_initramfs(<a href="#firecracker_initramfs-name">name</a>, <a href="#firecracker_initramfs-init">init</a>, <a href="#firecracker_initramfs-files">files</a>, <a href="#firecracker_initramfs-execs">execs</a>, <a href="#firecracker_initramfs-busybox">busybox</a>, <a href="#firecracker_initramfs-kwargs">**kwargs</a>)
</pre>

Pack a gzip-compressed newc cpio initramfs.

The archive contains a statically-linked busybox at `/bin/busybox` with
every applet symlinked into `/bin` (plus `init`, `mount`, `umount`, `sh`
in `/sbin`), `init` installed at `/init` (0755), an `/etc/fstab`, and the
empty mount points `/dev /proc /sys /tmp /run`. Packing uses busybox's own
`cpio` and `gzip`, so the only host tools needed are bash and coreutils.

Every ELF in `execs` (and `busybox`) is checked for a `PT_INTERP` program
header; a dynamically-linked binary fails the build, because the
initramfs has no libc or dynamic loader.

Output: `<name>.cpio.gz`.

Example:

```starlark
firecracker_initramfs(
    name = "hello_initrd",
    init = "hello_init.sh",
    files = {"greeting.txt": "/etc/greeting"},
)
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="firecracker_initramfs-name"></a>name |  target name; the output file is `<name>.cpio.gz`.   |  none |
| <a id="firecracker_initramfs-init"></a>init |  label of the script or static binary installed at `/init` (PID 1).   |  none |
| <a id="firecracker_initramfs-files"></a>files |  dict of `{label: absolute_destination_path}` installed 0644.   |  `{}` |
| <a id="firecracker_initramfs-execs"></a>execs |  dict of `{label: absolute_destination_path}` installed 0755; ELF entries must be statically linked.   |  `{}` |
| <a id="firecracker_initramfs-busybox"></a>busybox |  label of a statically-linked busybox. Default `@rules_firecracker//firecracker:busybox_static`.   |  `"@@//firecracker:busybox_static"` |
| <a id="firecracker_initramfs-kwargs"></a>kwargs |  forwarded to the underlying `genrule` (`visibility`, `tags`, ...).   |  none |


<a id="firecracker_install_cluster_test"></a>

## firecracker_install_cluster_test

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_install_cluster_test")

firecracker_install_cluster_test(<a href="#firecracker_install_cluster_test-name">name</a>, <a href="#firecracker_install_cluster_test-vm">vm</a>, <a href="#firecracker_install_cluster_test-installer">installer</a>, <a href="#firecracker_install_cluster_test-rootfs">rootfs</a>, <a href="#firecracker_install_cluster_test-nodes">nodes</a>, <a href="#firecracker_install_cluster_test-expect_marker">expect_marker</a>, <a href="#firecracker_install_cluster_test-gw">gw</a>, <a href="#firecracker_install_cluster_test-secret">secret</a>,
                                 <a href="#firecracker_install_cluster_test-timeout_seconds">timeout_seconds</a>, <a href="#firecracker_install_cluster_test-size">size</a>, <a href="#firecracker_install_cluster_test-visibility">visibility</a>, <a href="#firecracker_install_cluster_test-tags">tags</a>, <a href="#firecracker_install_cluster_test-kwargs">**kwargs</a>)
</pre>

Install each node to a GPT disk with an installer, then boot the disks.

Phase 1, per node IDX: create a sparse 5 GiB disk image, attach it with
`sudo losetup -fP`, write a `settings.ini`

```ini
[node]
role = server
[cluster]
cluster_secret = <secret>
[install]
target_disk = /dev/loopN
wipe_confirm = yes-i-am-sure
```

and run `sudo <installer> --settings <settings.ini> --rootfs-image <rootfs>`.
The installer must partition `target_disk` and lay down a bootable root
filesystem on partition 2. Phase 2 boots every node from its disk
(`FC_BOOT_DISK`, `root=/dev/vda2`) on a bridge at `gw`, like
`firecracker_cluster_test`, and passes iff `expect_marker` appears in a
console log. `vm` supplies the kernel, cmdline and machine size; its own
boot image is ignored.

`installer` may be a `go_binary` or any single-file executable target
(e.g. `sh_binary`). The host needs losetup, sgdisk, mkfs.fat, mkfs.ext4
and mkfs.exfat; the test SKIPs without them (fails with `FC_NO_SKIP=1`).
Same tags as `firecracker_cluster_test`.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="firecracker_install_cluster_test-name"></a>name |  target name of the `sh_test`.   |  none |
| <a id="firecracker_install_cluster_test-vm"></a>vm |  label of a `firecracker_microvm` (kernel/cmdline/size donor).   |  none |
| <a id="firecracker_install_cluster_test-installer"></a>installer |  label of the installer executable.   |  none |
| <a id="firecracker_install_cluster_test-rootfs"></a>rootfs |  label of the root filesystem image handed to the installer.   |  none |
| <a id="firecracker_install_cluster_test-nodes"></a>nodes |  `"IDX,IP,MAC,EXTRA"` node specs.   |  none |
| <a id="firecracker_install_cluster_test-expect_marker"></a>expect_marker |  string that must appear in a phase-2 log.   |  none |
| <a id="firecracker_install_cluster_test-gw"></a>gw |  bridge address (CIDR).   |  `"10.211.55.1/24"` |
| <a id="firecracker_install_cluster_test-secret"></a>secret |  value written to `cluster_secret` in each settings.ini.   |  `"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"` |
| <a id="firecracker_install_cluster_test-timeout_seconds"></a>timeout_seconds |  per-VM cap in seconds for phase 2.   |  `360` |
| <a id="firecracker_install_cluster_test-size"></a>size |  `sh_test` size.   |  `"enormous"` |
| <a id="firecracker_install_cluster_test-visibility"></a>visibility |  visibility of the `sh_test`.   |  `None` |
| <a id="firecracker_install_cluster_test-tags"></a>tags |  extra tags.   |  `None` |
| <a id="firecracker_install_cluster_test-kwargs"></a>kwargs |  forwarded to the `sh_test`.   |  none |


<a id="firecracker_k3s_test"></a>

## firecracker_k3s_test

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_k3s_test")

firecracker_k3s_test(<a href="#firecracker_k3s_test-name">name</a>, <a href="#firecracker_k3s_test-test_binary">test_binary</a>, <a href="#firecracker_k3s_test-scenario">scenario</a>, <a href="#firecracker_k3s_test-extra_manifests">extra_manifests</a>, <a href="#firecracker_k3s_test-extra_images">extra_images</a>, <a href="#firecracker_k3s_test-extra_files">extra_files</a>,
                     <a href="#firecracker_k3s_test-extra_execs">extra_execs</a>, <a href="#firecracker_k3s_test-timeout_seconds">timeout_seconds</a>, <a href="#firecracker_k3s_test-vcpus">vcpus</a>, <a href="#firecracker_k3s_test-mem_mib">mem_mib</a>, <a href="#firecracker_k3s_test-size_mb">size_mb</a>, <a href="#firecracker_k3s_test-kernel">kernel</a>, <a href="#firecracker_k3s_test-kernel_cmdline">kernel_cmdline</a>,
                     <a href="#firecracker_k3s_test-busybox">busybox</a>, <a href="#firecracker_k3s_test-k3s">k3s</a>, <a href="#firecracker_k3s_test-init">init</a>, <a href="#firecracker_k3s_test-firecracker">firecracker</a>, <a href="#firecracker_k3s_test-size">size</a>, <a href="#firecracker_k3s_test-visibility">visibility</a>, <a href="#firecracker_k3s_test-tags">tags</a>, <a href="#firecracker_k3s_test-kwargs">**kwargs</a>)
</pre>

Boot a single-node k3s server in a microVM and run a guest test against it.

The rootfs (built by `mkk3srootfs`) holds busybox, the static k3s binary
at `/usr/local/bin/k3s` (`kubectl`, `crictl`, `ctr` symlinks), the test
binary at `/usr/local/bin/<test_binary name>` and the default PID 1
(`k3s_init.sh`), which: starts `k3s server` on a dummy interface
(10.42.0.10, no NIC needed), waits for the node to be Ready, applies
`/etc/manifests/*.yaml`, then runs

```
<test_binary> --scenario=/etc/manifests/<scenario>.yaml \
    --report-json=/tmp/report.json \
    --kubeconfig=/etc/rancher/k3s/k3s.yaml --namespace=default
```

and prints the report between `===REPORT_BEGIN===` and
`===REPORT_END===` on the console before powering off. The host side
passes iff the report is a JSON object whose `pass_conditions` array is
non-empty and every entry has `"passed": true`. The report is saved as
`report.json` (and the console as `serial.log`) in the test's undeclared
outputs, and copied to `$SCENARIO_REPORT_PATH` when that is set and
writable.

Tags `requires-kvm` and `no-cache` are added.

Example:

```starlark
go_binary(name = "k3s_smoke", embed = [":k3s_smoke_lib"])  # static, cgo off

firecracker_k3s_test(
    name = "k3s_smoke_test",
    scenario = "k3s_smoke",
    test_binary = ":k3s_smoke",
)
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="firecracker_k3s_test-name"></a>name |  target name of the `sh_test`.   |  none |
| <a id="firecracker_k3s_test-test_binary"></a>test_binary |  label of a statically-linked guest test binary honoring the flags above.   |  none |
| <a id="firecracker_k3s_test-scenario"></a>scenario |  scenario name; written to `/etc/scenario` and passed as `--scenario=/etc/manifests/<scenario>.yaml`.   |  none |
| <a id="firecracker_k3s_test-extra_manifests"></a>extra_manifests |  dict `{label: basename.yaml}` copied to `/etc/manifests/` and `kubectl apply`'d once k3s is Ready.   |  `{}` |
| <a id="firecracker_k3s_test-extra_images"></a>extra_images |  dict `{label: basename.tar}` image tarballs copied to `/etc/images/` and preloaded into k3s' containerd (no registry pulls).   |  `{}` |
| <a id="firecracker_k3s_test-extra_files"></a>extra_files |  dict `{label: absolute_path}` installed 0644.   |  `{}` |
| <a id="firecracker_k3s_test-extra_execs"></a>extra_execs |  dict `{label: absolute_path}` installed 0755.   |  `{}` |
| <a id="firecracker_k3s_test-timeout_seconds"></a>timeout_seconds |  hard cap on VM wall time.   |  `300` |
| <a id="firecracker_k3s_test-vcpus"></a>vcpus |  number of vCPUs (2 is the practical minimum for k3s).   |  `2` |
| <a id="firecracker_k3s_test-mem_mib"></a>mem_mib |  guest memory in MiB.   |  `2048` |
| <a id="firecracker_k3s_test-size_mb"></a>size_mb |  rootfs size in MiB.   |  `2048` |
| <a id="firecracker_k3s_test-kernel"></a>kernel |  guest kernel. Default `@rules_firecracker//firecracker:vmlinux`.   |  `"@@//firecracker:vmlinux"` |
| <a id="firecracker_k3s_test-kernel_cmdline"></a>kernel_cmdline |  kernel boot arguments.   |  `"console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on"` |
| <a id="firecracker_k3s_test-busybox"></a>busybox |  static busybox label.   |  `"@@//firecracker:busybox_static"` |
| <a id="firecracker_k3s_test-k3s"></a>k3s |  static k3s label. Default `@rules_firecracker//firecracker:k3s_binary`.   |  `"@@//firecracker:k3s_binary"` |
| <a id="firecracker_k3s_test-init"></a>init |  `/sbin/init` script. Default `@rules_firecracker//firecracker:k3s_init`.   |  `"@@//firecracker:k3s_init"` |
| <a id="firecracker_k3s_test-firecracker"></a>firecracker |  firecracker VMM binary; see `firecracker_microvm`.   |  `"@@//firecracker:firecracker"` |
| <a id="firecracker_k3s_test-size"></a>size |  `sh_test` size.   |  `"enormous"` |
| <a id="firecracker_k3s_test-visibility"></a>visibility |  visibility of the `sh_test`.   |  `None` |
| <a id="firecracker_k3s_test-tags"></a>tags |  extra tags; `requires-kvm` and `no-cache` are always added.   |  `None` |
| <a id="firecracker_k3s_test-kwargs"></a>kwargs |  forwarded to the `sh_test`.   |  none |


<a id="firecracker_microvm"></a>

## firecracker_microvm

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_microvm")

firecracker_microvm(<a href="#firecracker_microvm-name">name</a>, <a href="#firecracker_microvm-kernel">kernel</a>, <a href="#firecracker_microvm-initrd">initrd</a>, <a href="#firecracker_microvm-rootfs">rootfs</a>, <a href="#firecracker_microvm-extra_drive">extra_drive</a>, <a href="#firecracker_microvm-kernel_cmdline">kernel_cmdline</a>, <a href="#firecracker_microvm-vcpus">vcpus</a>, <a href="#firecracker_microvm-mem_mib">mem_mib</a>,
                    <a href="#firecracker_microvm-firecracker">firecracker</a>, <a href="#firecracker_microvm-visibility">visibility</a>, <a href="#firecracker_microvm-tags">tags</a>, <a href="#firecracker_microvm-kwargs">**kwargs</a>)
</pre>

A runnable `sh_binary` that boots a firecracker microVM.

`bazel run` it (needs `/dev/kvm`) to boot the VM with the serial console
on stdout. The launcher resolves the kernel, boot image and the
firecracker binary through runfiles, writes a `vm.json` into a fresh
temp dir and runs `firecracker --no-api --config-file vm.json`.

Boot modes (exactly one of `initrd` / `rootfs`):

* `initrd`: boots the cpio.gz as an initramfs; `extra_drive`, if set, is
  the only block device (`/dev/vda`).
* `rootfs`: boots the ext4 image as `/dev/vda` (`root=/dev/vda` is
  appended to the cmdline). The image is copied, so the VM may write it;
  `extra_drive`, if set, is `/dev/vdb`.

Runtime environment variables understood by the launcher:

* `FC_TIMEOUT=<secs>`: SIGKILL the VM after this many seconds and exit 0.
* `FC_KEEP_WORK=1`: keep the temp dir (with `extra.img`) for inspection.
* `FC_TAP`, `FC_GUEST_MAC`: attach a virtio-net NIC on host TAP `FC_TAP`.
* `FC_CMDLINE_EXTRA`: appended to the kernel cmdline (e.g. `ip=...`).
* `FC_PERSIST_DISK=<path>`: (rootfs mode) attach this host file in place
  as the last writable drive (`/dev/vdb`, or `/dev/vdc` after an
  `extra_drive`); its contents survive reboots.
* `FC_BOOT_DISK=<path>`, `FC_ROOT_PART`: boot from a partitioned disk
  image instead (root defaults to `/dev/vda2`).
* `FC_FIRECRACKER=<path>`: use this firecracker binary instead of the
  one from runfiles (debugging only).

The target is always tagged `manual`.

Example:

```starlark
firecracker_microvm(
    name = "hello_vm",
    initrd = ":hello_initrd",
    mem_mib = 128,
)
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="firecracker_microvm-name"></a>name |  target name of the runnable `sh_binary`.   |  none |
| <a id="firecracker_microvm-kernel"></a>kernel |  label of an uncompressed x86_64 kernel ELF (`vmlinux`). Default `@rules_firecracker//firecracker:vmlinux`.   |  `"@@//firecracker:vmlinux"` |
| <a id="firecracker_microvm-initrd"></a>initrd |  label of a cpio.gz initramfs. Mutually exclusive with `rootfs`.   |  `None` |
| <a id="firecracker_microvm-rootfs"></a>rootfs |  label of an ext4 root image. Mutually exclusive with `initrd`.   |  `None` |
| <a id="firecracker_microvm-extra_drive"></a>extra_drive |  optional label of a disk image attached as an additional writable virtio-block device. It is copied into the temp dir first (the bazel output stays immutable): `/dev/vda` in initrd mode, `/dev/vdb` in rootfs mode.   |  `None` |
| <a id="firecracker_microvm-kernel_cmdline"></a>kernel_cmdline |  kernel boot arguments. Default `console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on`.   |  `"console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on"` |
| <a id="firecracker_microvm-vcpus"></a>vcpus |  number of vCPUs.   |  `1` |
| <a id="firecracker_microvm-mem_mib"></a>mem_mib |  guest memory in MiB.   |  `256` |
| <a id="firecracker_microvm-firecracker"></a>firecracker |  label of a single executable file: the firecracker VMM to run. Default `@rules_firecracker//firecracker:firecracker` (the pinned upstream release for the target CPU).   |  `"@@//firecracker:firecracker"` |
| <a id="firecracker_microvm-visibility"></a>visibility |  visibility of the `sh_binary`.   |  `None` |
| <a id="firecracker_microvm-tags"></a>tags |  extra tags; `manual` is always added.   |  `None` |
| <a id="firecracker_microvm-kwargs"></a>kwargs |  forwarded to the `sh_binary`.   |  none |


<a id="firecracker_renumber_test"></a>

## firecracker_renumber_test

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_renumber_test")

firecracker_renumber_test(<a href="#firecracker_renumber_test-name">name</a>, <a href="#firecracker_renumber_test-vm">vm</a>, <a href="#firecracker_renumber_test-nodes1">nodes1</a>, <a href="#firecracker_renumber_test-nodes2">nodes2</a>, <a href="#firecracker_renumber_test-gw1">gw1</a>, <a href="#firecracker_renumber_test-gw2">gw2</a>, <a href="#firecracker_renumber_test-expect_marker">expect_marker</a>, <a href="#firecracker_renumber_test-timeout1">timeout1</a>, <a href="#firecracker_renumber_test-timeout2">timeout2</a>,
                          <a href="#firecracker_renumber_test-size">size</a>, <a href="#firecracker_renumber_test-visibility">visibility</a>, <a href="#firecracker_renumber_test-tags">tags</a>, <a href="#firecracker_renumber_test-kwargs">**kwargs</a>)
</pre>

Two-phase multi-VM test: boot a cluster, then reboot it on a new subnet.

Phase 1 boots `nodes1` on a bridge at `gw1`, exactly like
`firecracker_cluster_test`, with every node given a persistent data disk
(`FC_PERSIST_DISK`, a 2 GiB ext4 image at `/dev/vdb` in the guest,
created once per IDX). Phase 2 boots `nodes2` on `gw2` with the SAME
disks (match nodes by IDX). The test passes iff `expect_marker` appears
in a phase-2 console log. `vm` must be a rootfs-mode microvm (the
persistent disk is attached only in rootfs mode).

Same tags, SKIP and `FC_NO_SKIP` behavior as `firecracker_cluster_test`.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="firecracker_renumber_test-name"></a>name |  target name of the `sh_test`.   |  none |
| <a id="firecracker_renumber_test-vm"></a>vm |  label of a rootfs-mode `firecracker_microvm`.   |  none |
| <a id="firecracker_renumber_test-nodes1"></a>nodes1 |  phase-1 `"IDX,IP,MAC,EXTRA"` node specs.   |  none |
| <a id="firecracker_renumber_test-nodes2"></a>nodes2 |  phase-2 node specs (same IDXs, new IPs).   |  none |
| <a id="firecracker_renumber_test-gw1"></a>gw1 |  phase-1 bridge address (CIDR).   |  none |
| <a id="firecracker_renumber_test-gw2"></a>gw2 |  phase-2 bridge address (CIDR).   |  none |
| <a id="firecracker_renumber_test-expect_marker"></a>expect_marker |  string that must appear in a phase-2 log.   |  none |
| <a id="firecracker_renumber_test-timeout1"></a>timeout1 |  phase-1 per-VM cap in seconds.   |  `240` |
| <a id="firecracker_renumber_test-timeout2"></a>timeout2 |  phase-2 per-VM cap in seconds.   |  `300` |
| <a id="firecracker_renumber_test-size"></a>size |  `sh_test` size.   |  `"enormous"` |
| <a id="firecracker_renumber_test-visibility"></a>visibility |  visibility of the `sh_test`.   |  `None` |
| <a id="firecracker_renumber_test-tags"></a>tags |  extra tags.   |  `None` |
| <a id="firecracker_renumber_test-kwargs"></a>kwargs |  forwarded to the `sh_test`.   |  none |


<a id="firecracker_rootfs"></a>

## firecracker_rootfs

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_rootfs")

firecracker_rootfs(<a href="#firecracker_rootfs-name">name</a>, <a href="#firecracker_rootfs-size_mb">size_mb</a>, <a href="#firecracker_rootfs-label">label</a>, <a href="#firecracker_rootfs-files">files</a>, <a href="#firecracker_rootfs-execs">execs</a>, <a href="#firecracker_rootfs-kwargs">**kwargs</a>)
</pre>

Build an ext4 disk image from a set of files with `mkfs.ext4 -d`.

No root, mount or loop device is needed; the host must have e2fsprogs
>= 1.43. The image only contains what you put in it: to boot it as a
root filesystem, supply a PID 1 (e.g. busybox at `/bin/busybox` plus a
script at `/sbin/init`) and pass `init=/sbin/init` in the microvm's
`kernel_cmdline`. It can equally serve as a data disk for
`firecracker_microvm(extra_drive = ...)`.

The genrule is `local` (unsandboxed, never remote-cached) because the
image is a sparse file of `size_mb` that caches would store densely.

Output: `<name>.ext4`.

Example:

```starlark
firecracker_rootfs(
    name = "hello_rootfs",
    size_mb = 16,
    label = "hello",
    execs = {
        "@rules_firecracker//firecracker:busybox_static": "/bin/busybox",
        "hello_rootfs_init.sh": "/sbin/init",
    },
)

firecracker_microvm(
    name = "hello_rootfs_vm",
    rootfs = ":hello_rootfs",
    kernel_cmdline = DEFAULT_KERNEL_CMDLINE + " rw init=/sbin/init",
    mem_mib = 128,
)
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="firecracker_rootfs-name"></a>name |  target name; the output file is `<name>.ext4`.   |  none |
| <a id="firecracker_rootfs-size_mb"></a>size_mb |  image size in MiB (sparse).   |  none |
| <a id="firecracker_rootfs-label"></a>label |  ext4 filesystem label (max 16 characters).   |  none |
| <a id="firecracker_rootfs-files"></a>files |  dict of `{label: absolute_destination_path}` installed 0644.   |  `{}` |
| <a id="firecracker_rootfs-execs"></a>execs |  dict of `{label: absolute_destination_path}` installed 0755.   |  `{}` |
| <a id="firecracker_rootfs-kwargs"></a>kwargs |  forwarded to the underlying `genrule` (`visibility`, `tags`, ...).   |  none |


<a id="firecracker_test"></a>

## firecracker_test

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_test")

firecracker_test(<a href="#firecracker_test-name">name</a>, <a href="#firecracker_test-microvm">microvm</a>, <a href="#firecracker_test-expect_markers">expect_markers</a>, <a href="#firecracker_test-unexpected_markers">unexpected_markers</a>, <a href="#firecracker_test-timeout_seconds">timeout_seconds</a>, <a href="#firecracker_test-size">size</a>,
                 <a href="#firecracker_test-visibility">visibility</a>, <a href="#firecracker_test-tags">tags</a>, <a href="#firecracker_test-kwargs">**kwargs</a>)
</pre>

An `sh_test` that boots a microvm and asserts on its serial console.

The test runs the `firecracker_microvm` launcher with
`FC_TIMEOUT=timeout_seconds`, streams the console to the test log, and:

* kills the VM as soon as every `expect_markers` string has appeared
  (so a passing test takes seconds, not `timeout_seconds`);
* otherwise lets it run until it exits on its own (e.g. `poweroff -f`)
  or the timeout kills it; a kill by the timeout is not itself a failure;
* then fails if any `expect_markers` string is missing or any
  `unexpected_markers` string is present (fixed-string match).

Tags `requires-kvm` and `no-cache` are added. Run with `--config=kvm`
(see README) so `/dev/kvm` is mounted into the sandbox.

Example:

```starlark
firecracker_test(
    name = "hello_test",
    microvm = ":hello_vm",
    expect_markers = ["HELLO_FROM_INITRD"],
    unexpected_markers = ["Kernel panic"],
)
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="firecracker_test-name"></a>name |  target name of the `sh_test`.   |  none |
| <a id="firecracker_test-microvm"></a>microvm |  label of a `firecracker_microvm` (or `firecracker_container`).   |  none |
| <a id="firecracker_test-expect_markers"></a>expect_markers |  strings that must all appear on the console.   |  `[]` |
| <a id="firecracker_test-unexpected_markers"></a>unexpected_markers |  strings that must not appear on the console.   |  `[]` |
| <a id="firecracker_test-timeout_seconds"></a>timeout_seconds |  hard cap on VM wall time in seconds.   |  `30` |
| <a id="firecracker_test-size"></a>size |  `sh_test` size.   |  `"medium"` |
| <a id="firecracker_test-visibility"></a>visibility |  visibility of the `sh_test`.   |  `None` |
| <a id="firecracker_test-tags"></a>tags |  extra tags; `requires-kvm` and `no-cache` are always added.   |  `None` |
| <a id="firecracker_test-kwargs"></a>kwargs |  forwarded to the `sh_test` (e.g. `timeout`, `flaky`).   |  none |


