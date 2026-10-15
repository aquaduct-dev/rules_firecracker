<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Bazel rules for booting real Linux VMs in your tests, using Firecracker.

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

<a id="firecracker_cluster_test"></a>

## firecracker_cluster_test

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_cluster_test")

firecracker_cluster_test(<a href="#firecracker_cluster_test-name">name</a>, <a href="#firecracker_cluster_test-vm">vm</a>, <a href="#firecracker_cluster_test-nodes">nodes</a>, <a href="#firecracker_cluster_test-expect_marker">expect_marker</a>, <a href="#firecracker_cluster_test-leader_idx">leader_idx</a>, <a href="#firecracker_cluster_test-subnet_gw">subnet_gw</a>, <a href="#firecracker_cluster_test-timeout_seconds">timeout_seconds</a>,
                         <a href="#firecracker_cluster_test-size">size</a>, <a href="#firecracker_cluster_test-visibility">visibility</a>, <a href="#firecracker_cluster_test-tags">tags</a>, <a href="#firecracker_cluster_test-kwargs">**kwargs</a>)
</pre>

Boot several copies of one VM on a shared network and check their logs.

The test creates a Linux bridge on the host, with the address
`subnet_gw`, and one TAP device per node, using `sudo -n ip ...`. It
boots every node at the same time. Each one gets
`ip=<IP>::<GW>:<MASK>::eth0:off <EXTRA>` on its kernel command line. It
waits for all the VMs to exit, or for `timeout_seconds`, then removes the
network. It passes if `expect_marker` appears in any node's console log.

Each `nodes` entry is `"IDX,IP,MAC,EXTRA"`:

* `IDX` is a small number naming the node. Its TAP device is
  `fct<pid>_<IDX>` and its console log is `vm<IDX>.log`.
* `IP` is the guest's IPv4 address.
* `MAC` is the guest's MAC address.
* `EXTRA` is more kernel command line arguments. It can contain spaces
  but not commas.

If two cluster tests might run at the same time, give them different
subnets.

The network setup needs root, so the test runs outside Bazel's sandbox.
It's tagged `requires-kvm`, `no-cache`, `local`, `no-sandbox` and
`manual`. If `/dev/kvm` or passwordless sudo is missing, it prints SKIP
and passes. Set `FC_NO_SKIP=1` in the test environment to make that a
failure.

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
| <a id="firecracker_cluster_test-name"></a>name |  name of the test.   |  none |
| <a id="firecracker_cluster_test-vm"></a>vm |  the `firecracker_microvm` every node boots.   |  none |
| <a id="firecracker_cluster_test-nodes"></a>nodes |  one `"IDX,IP,MAC,EXTRA"` string per node.   |  none |
| <a id="firecracker_cluster_test-expect_marker"></a>expect_marker |  must appear in at least one node's console log.   |  none |
| <a id="firecracker_cluster_test-leader_idx"></a>leader_idx |  IDX of the node whose log is printed at the end.   |  none |
| <a id="firecracker_cluster_test-subnet_gw"></a>subnet_gw |  the bridge address in CIDR form. It's also the VMs' gateway.   |  `"10.211.55.1/24"` |
| <a id="firecracker_cluster_test-timeout_seconds"></a>timeout_seconds |  the longest each VM may run, in seconds.   |  `360` |
| <a id="firecracker_cluster_test-size"></a>size |  test size.   |  `"enormous"` |
| <a id="firecracker_cluster_test-visibility"></a>visibility |  visibility of the test.   |  `None` |
| <a id="firecracker_cluster_test-tags"></a>tags |  extra tags. The tags listed above are always added.   |  `None` |
| <a id="firecracker_cluster_test-kwargs"></a>kwargs |  passed to the `sh_test` underneath.   |  none |


<a id="firecracker_container"></a>

## firecracker_container

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_container")

firecracker_container(<a href="#firecracker_container-name">name</a>, <a href="#firecracker_container-image">image</a>, <a href="#firecracker_container-size_mb">size_mb</a>, <a href="#firecracker_container-kernel">kernel</a>, <a href="#firecracker_container-extra_env">extra_env</a>, <a href="#firecracker_container-extra_args">extra_args</a>, <a href="#firecracker_container-kernel_cmdline">kernel_cmdline</a>, <a href="#firecracker_container-vcpus">vcpus</a>,
                      <a href="#firecracker_container-mem_mib">mem_mib</a>, <a href="#firecracker_container-busybox">busybox</a>, <a href="#firecracker_container-firecracker">firecracker</a>, <a href="#firecracker_container-visibility">visibility</a>, <a href="#firecracker_container-tags">tags</a>, <a href="#firecracker_container-kwargs">**kwargs</a>)
</pre>

Boot one OCI image as the whole VM.

The image's layers are merged into an ext4 root filesystem. Deleted
files and opaque directories are handled. A static busybox goes in at
`/sbin/busybox`, and a generated `/sbin/init` replaces any init the
image has. That init mounts `/proc`, `/sys`, `/dev`, `/tmp` and `/run`,
sets the image's `Env` and then `extra_env`, and changes to the image's
`WorkingDir`. Then it prints `FIRECRACKER_CONTAINER_READY`, runs
`Entrypoint + Cmd + extra_args`, prints
`FIRECRACKER_CONTAINER_EXIT=<exit code>`, and reboots. With `reboot=k`
on the command line, which the default has, the reboot ends the VM.

You get a `firecracker_microvm` named `name`, plus a helper target
`_<name>__rootfs` that builds the image locally. The host needs
e2fsprogs, python3 and tar, and zstd for zstd-compressed layers.

Example, using rules_oci:

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
| <a id="firecracker_container-name"></a>name |  name of the VM target.   |  none |
| <a id="firecracker_container-image"></a>image |  an `oci_image`, or any target that produces an OCI image layout directory (`index.json` and `blobs/sha256/...`).   |  none |
| <a id="firecracker_container-size_mb"></a>size_mb |  root filesystem size in MiB. It must be bigger than the merged image.   |  `512` |
| <a id="firecracker_container-kernel"></a>kernel |  guest kernel. Default `@rules_firecracker//firecracker:vmlinux`.   |  `"@@//firecracker:vmlinux"` |
| <a id="firecracker_container-extra_env"></a>extra_env |  dict of `{KEY: VALUE}`. Set after the image's `Env`, so these win.   |  `{}` |
| <a id="firecracker_container-extra_args"></a>extra_args |  arguments added after `Entrypoint + Cmd`.   |  `[]` |
| <a id="firecracker_container-kernel_cmdline"></a>kernel_cmdline |  kernel boot arguments. The default includes `init=/sbin/init` so the generated init runs, not one from the image.   |  `"console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on init=/sbin/init"` |
| <a id="firecracker_container-vcpus"></a>vcpus |  number of vCPUs.   |  `1` |
| <a id="firecracker_container-mem_mib"></a>mem_mib |  guest memory in MiB.   |  `512` |
| <a id="firecracker_container-busybox"></a>busybox |  static busybox, copied to `/sbin/busybox`.   |  `"@@//firecracker:busybox_static"` |
| <a id="firecracker_container-firecracker"></a>firecracker |  the firecracker binary. See `firecracker_microvm`.   |  `"@@//firecracker:firecracker"` |
| <a id="firecracker_container-visibility"></a>visibility |  visibility of the VM target.   |  `None` |
| <a id="firecracker_container-tags"></a>tags |  extra tags for the VM target. `manual` is always added.   |  `None` |
| <a id="firecracker_container-kwargs"></a>kwargs |  passed to `firecracker_microvm`.   |  none |


<a id="firecracker_initramfs"></a>

## firecracker_initramfs

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_initramfs")

firecracker_initramfs(<a href="#firecracker_initramfs-name">name</a>, <a href="#firecracker_initramfs-init">init</a>, <a href="#firecracker_initramfs-files">files</a>, <a href="#firecracker_initramfs-execs">execs</a>, <a href="#firecracker_initramfs-busybox">busybox</a>, <a href="#firecracker_initramfs-kwargs">**kwargs</a>)
</pre>

Pack files into an initramfs (a gzip-compressed cpio archive).

The archive gets a static busybox at `/bin/busybox`, with every applet
linked into `/bin` and `init`, `mount`, `umount` and `sh` linked into
`/sbin`. It also gets your `init` at `/init`, an `/etc/fstab`, and empty
`/dev`, `/proc`, `/sys`, `/tmp` and `/run` directories. Packing uses
busybox's own `cpio` and `gzip`, so the host only needs bash and
coreutils.

The initramfs has no libc, so dynamically linked programs can't run in
it. The build checks every ELF file in `execs` (and busybox itself) and
fails if one is dynamically linked.

The output is `<name>.cpio.gz`.

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
| <a id="firecracker_initramfs-name"></a>name |  target name. The output file is `<name>.cpio.gz`.   |  none |
| <a id="firecracker_initramfs-init"></a>init |  script or static binary to run as PID 1. Installed at `/init`.   |  none |
| <a id="firecracker_initramfs-files"></a>files |  dict of `{label: absolute_path}`. Installed with mode 0644.   |  `{}` |
| <a id="firecracker_initramfs-execs"></a>execs |  dict of `{label: absolute_path}`. Installed with mode 0755. ELF files must be statically linked.   |  `{}` |
| <a id="firecracker_initramfs-busybox"></a>busybox |  a static busybox. Default `@rules_firecracker//firecracker:busybox_static`.   |  `"@@//firecracker:busybox_static"` |
| <a id="firecracker_initramfs-kwargs"></a>kwargs |  passed to the `genrule` underneath (`visibility`, `tags`, ...).   |  none |


<a id="firecracker_install_cluster_test"></a>

## firecracker_install_cluster_test

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_install_cluster_test")

firecracker_install_cluster_test(<a href="#firecracker_install_cluster_test-name">name</a>, <a href="#firecracker_install_cluster_test-vm">vm</a>, <a href="#firecracker_install_cluster_test-installer">installer</a>, <a href="#firecracker_install_cluster_test-rootfs">rootfs</a>, <a href="#firecracker_install_cluster_test-nodes">nodes</a>, <a href="#firecracker_install_cluster_test-expect_marker">expect_marker</a>, <a href="#firecracker_install_cluster_test-gw">gw</a>, <a href="#firecracker_install_cluster_test-secret">secret</a>,
                                 <a href="#firecracker_install_cluster_test-timeout_seconds">timeout_seconds</a>, <a href="#firecracker_install_cluster_test-size">size</a>, <a href="#firecracker_install_cluster_test-visibility">visibility</a>, <a href="#firecracker_install_cluster_test-tags">tags</a>, <a href="#firecracker_install_cluster_test-kwargs">**kwargs</a>)
</pre>

Install each node to a blank disk, then boot the cluster from the disks.

Phase 1 runs once per node. It creates a sparse 5 GiB disk image,
attaches it with `sudo losetup -fP`, and writes a `settings.ini`:

```ini
[node]
role = server
[cluster]
cluster_secret = <secret>
[install]
target_disk = /dev/loopN
wipe_confirm = yes-i-am-sure
```

Then it runs `sudo <installer> --settings <settings.ini> --rootfs-image <rootfs>`.
Your installer has to partition `target_disk` and put a bootable root
filesystem on partition 2.

Phase 2 boots every node from its disk (`root=/dev/vda2`) on a bridge at
`gw`, the same way `firecracker_cluster_test` does. The test passes if
`expect_marker` appears in a console log. `vm` only supplies the kernel,
the command line and the machine size. Its own boot image isn't used.

`installer` can be a `go_binary` or any other single-file program, like
an `sh_binary`. The host needs losetup, sgdisk, mkfs.fat, mkfs.ext4 and
mkfs.exfat. Without them the test skips, or fails with `FC_NO_SKIP=1`.
Tags work the same as in `firecracker_cluster_test`.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="firecracker_install_cluster_test-name"></a>name |  name of the test.   |  none |
| <a id="firecracker_install_cluster_test-vm"></a>vm |  a `firecracker_microvm` to take the kernel, command line and size from.   |  none |
| <a id="firecracker_install_cluster_test-installer"></a>installer |  your installer program.   |  none |
| <a id="firecracker_install_cluster_test-rootfs"></a>rootfs |  the root filesystem image passed to the installer.   |  none |
| <a id="firecracker_install_cluster_test-nodes"></a>nodes |  `"IDX,IP,MAC,EXTRA"` node specs.   |  none |
| <a id="firecracker_install_cluster_test-expect_marker"></a>expect_marker |  must appear in a phase 2 log.   |  none |
| <a id="firecracker_install_cluster_test-gw"></a>gw |  bridge address in CIDR form.   |  `"10.211.55.1/24"` |
| <a id="firecracker_install_cluster_test-secret"></a>secret |  written as `cluster_secret` in each `settings.ini`.   |  `"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"` |
| <a id="firecracker_install_cluster_test-timeout_seconds"></a>timeout_seconds |  the longest each VM may run in phase 2, in seconds.   |  `360` |
| <a id="firecracker_install_cluster_test-size"></a>size |  test size.   |  `"enormous"` |
| <a id="firecracker_install_cluster_test-visibility"></a>visibility |  visibility of the test.   |  `None` |
| <a id="firecracker_install_cluster_test-tags"></a>tags |  extra tags.   |  `None` |
| <a id="firecracker_install_cluster_test-kwargs"></a>kwargs |  passed to the `sh_test` underneath.   |  none |


<a id="firecracker_k3s_test"></a>

## firecracker_k3s_test

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_k3s_test")

firecracker_k3s_test(<a href="#firecracker_k3s_test-name">name</a>, <a href="#firecracker_k3s_test-test_binary">test_binary</a>, <a href="#firecracker_k3s_test-scenario">scenario</a>, <a href="#firecracker_k3s_test-extra_manifests">extra_manifests</a>, <a href="#firecracker_k3s_test-extra_images">extra_images</a>, <a href="#firecracker_k3s_test-extra_files">extra_files</a>,
                     <a href="#firecracker_k3s_test-extra_execs">extra_execs</a>, <a href="#firecracker_k3s_test-timeout_seconds">timeout_seconds</a>, <a href="#firecracker_k3s_test-vcpus">vcpus</a>, <a href="#firecracker_k3s_test-mem_mib">mem_mib</a>, <a href="#firecracker_k3s_test-size_mb">size_mb</a>, <a href="#firecracker_k3s_test-kernel">kernel</a>, <a href="#firecracker_k3s_test-kernel_cmdline">kernel_cmdline</a>,
                     <a href="#firecracker_k3s_test-busybox">busybox</a>, <a href="#firecracker_k3s_test-k3s">k3s</a>, <a href="#firecracker_k3s_test-init">init</a>, <a href="#firecracker_k3s_test-firecracker">firecracker</a>, <a href="#firecracker_k3s_test-size">size</a>, <a href="#firecracker_k3s_test-visibility">visibility</a>, <a href="#firecracker_k3s_test-tags">tags</a>, <a href="#firecracker_k3s_test-kwargs">**kwargs</a>)
</pre>

Start k3s in a VM and run your test program against it.

The VM's disk is built by `mkk3srootfs`. It holds busybox, k3s at
`/usr/local/bin/k3s` (with `kubectl`, `crictl` and `ctr` links), your
test program at `/usr/local/bin/<its target name>`, and the init script.

The init script (`k3s_init.sh` by default) starts `k3s server` on a
dummy interface at 10.42.0.10, so the VM needs no network card. It waits
for the node to be ready, applies `/etc/manifests/*.yaml`, and runs

```
<test_binary> --scenario=/etc/manifests/<scenario>.yaml \
    --report-json=/tmp/report.json \
    --kubeconfig=/etc/rancher/k3s/k3s.yaml --namespace=default
```

Then it prints the report between `===REPORT_BEGIN===` and
`===REPORT_END===` and reboots, which ends the VM.

The test passes only if the report is a JSON object whose
`pass_conditions` array has at least one entry, and every entry has
`"passed": true`. The report is saved as `report.json`, and the console
as `serial.log`, in the test's undeclared outputs. If
`$SCENARIO_REPORT_PATH` is set and writable, the report is copied there
too.

It adds the tags `requires-kvm` and `no-cache`.

Example:

```starlark
go_binary(name = "k3s_smoke", embed = [":k3s_smoke_lib"])  # static, no cgo

firecracker_k3s_test(
    name = "k3s_smoke_test",
    scenario = "k3s_smoke",
    test_binary = ":k3s_smoke",
)
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="firecracker_k3s_test-name"></a>name |  name of the test.   |  none |
| <a id="firecracker_k3s_test-test_binary"></a>test_binary |  your test program. It must be statically linked and accept the flags above.   |  none |
| <a id="firecracker_k3s_test-scenario"></a>scenario |  a scenario name. It's written to `/etc/scenario` and passed as `--scenario=/etc/manifests/<scenario>.yaml`.   |  none |
| <a id="firecracker_k3s_test-extra_manifests"></a>extra_manifests |  dict of `{label: file_name.yaml}`. Copied into `/etc/manifests/` and applied with `kubectl apply` once k3s is ready.   |  `{}` |
| <a id="firecracker_k3s_test-extra_images"></a>extra_images |  dict of `{label: file_name.tar}`. Image tarballs, copied into `/etc/images/` and loaded into k3s, so nothing is pulled from a registry.   |  `{}` |
| <a id="firecracker_k3s_test-extra_files"></a>extra_files |  dict of `{label: absolute_path}`. Installed with mode 0644.   |  `{}` |
| <a id="firecracker_k3s_test-extra_execs"></a>extra_execs |  dict of `{label: absolute_path}`. Installed with mode 0755.   |  `{}` |
| <a id="firecracker_k3s_test-timeout_seconds"></a>timeout_seconds |  the longest the VM may run, in seconds.   |  `300` |
| <a id="firecracker_k3s_test-vcpus"></a>vcpus |  number of vCPUs. k3s needs at least 2.   |  `2` |
| <a id="firecracker_k3s_test-mem_mib"></a>mem_mib |  guest memory in MiB.   |  `2048` |
| <a id="firecracker_k3s_test-size_mb"></a>size_mb |  disk size in MiB.   |  `2048` |
| <a id="firecracker_k3s_test-kernel"></a>kernel |  guest kernel. Default `@rules_firecracker//firecracker:vmlinux`.   |  `"@@//firecracker:vmlinux"` |
| <a id="firecracker_k3s_test-kernel_cmdline"></a>kernel_cmdline |  kernel boot arguments.   |  `"console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on"` |
| <a id="firecracker_k3s_test-busybox"></a>busybox |  static busybox.   |  `"@@//firecracker:busybox_static"` |
| <a id="firecracker_k3s_test-k3s"></a>k3s |  static k3s. Default `@rules_firecracker//firecracker:k3s_binary`.   |  `"@@//firecracker:k3s_binary"` |
| <a id="firecracker_k3s_test-init"></a>init |  the init script, installed at `/sbin/init`. Default `@rules_firecracker//firecracker:k3s_init`.   |  `"@@//firecracker:k3s_init"` |
| <a id="firecracker_k3s_test-firecracker"></a>firecracker |  the firecracker binary. See `firecracker_microvm`.   |  `"@@//firecracker:firecracker"` |
| <a id="firecracker_k3s_test-size"></a>size |  test size.   |  `"enormous"` |
| <a id="firecracker_k3s_test-visibility"></a>visibility |  visibility of the test.   |  `None` |
| <a id="firecracker_k3s_test-tags"></a>tags |  extra tags. `requires-kvm` and `no-cache` are always added.   |  `None` |
| <a id="firecracker_k3s_test-kwargs"></a>kwargs |  passed to the `sh_test` underneath.   |  none |


<a id="firecracker_microvm"></a>

## firecracker_microvm

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_microvm")

firecracker_microvm(<a href="#firecracker_microvm-name">name</a>, <a href="#firecracker_microvm-kernel">kernel</a>, <a href="#firecracker_microvm-initrd">initrd</a>, <a href="#firecracker_microvm-rootfs">rootfs</a>, <a href="#firecracker_microvm-extra_drive">extra_drive</a>, <a href="#firecracker_microvm-kernel_cmdline">kernel_cmdline</a>, <a href="#firecracker_microvm-vcpus">vcpus</a>, <a href="#firecracker_microvm-mem_mib">mem_mib</a>,
                    <a href="#firecracker_microvm-firecracker">firecracker</a>, <a href="#firecracker_microvm-visibility">visibility</a>, <a href="#firecracker_microvm-tags">tags</a>, <a href="#firecracker_microvm-kwargs">**kwargs</a>)
</pre>

Create a target you can `bazel run` to boot a VM.

The VM's console prints to your terminal. Running it needs `/dev/kvm`.
The launcher finds the kernel, the boot image and the firecracker binary
in its runfiles, writes a `vm.json` config into a new temp directory, and
runs `firecracker --no-api --config-file vm.json`.

Set exactly one of `initrd` or `rootfs`:

* `initrd` boots the initramfs. If you set `extra_drive`, it's the only
  disk, `/dev/vda`.
* `rootfs` boots the ext4 image as `/dev/vda` and adds `root=/dev/vda`
  to the command line. The image is copied first, so the VM can write
  to it. If you set `extra_drive`, it's `/dev/vdb`.

These environment variables change what happens when you run it:

* `FC_TIMEOUT=<secs>`: kill the VM after this many seconds and exit 0.
* `FC_KEEP_WORK=1`: keep the temp directory (with `extra.img`) so you
  can look at it.
* `FC_TAP`, `FC_GUEST_MAC`: add a network card on the host TAP device
  `FC_TAP`.
* `FC_CMDLINE_EXTRA`: add arguments to the kernel command line, like
  `ip=...`.
* `FC_PERSIST_DISK=<path>`: rootfs mode only. Attach this host file
  directly as the last disk (`/dev/vdb`, or `/dev/vdc` after an
  `extra_drive`). Changes survive reboots.
* `FC_BOOT_DISK=<path>`, `FC_ROOT_PART`: boot from a partitioned disk
  image instead. The root partition defaults to `/dev/vda2`.
* `FC_FIRECRACKER=<path>`: run this firecracker binary instead of the
  one in runfiles. Meant for debugging.

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
| <a id="firecracker_microvm-name"></a>name |  name of the target you run.   |  none |
| <a id="firecracker_microvm-kernel"></a>kernel |  an uncompressed x86_64 kernel ELF (`vmlinux`). Default `@rules_firecracker//firecracker:vmlinux`.   |  `"@@//firecracker:vmlinux"` |
| <a id="firecracker_microvm-initrd"></a>initrd |  an initramfs to boot from. Don't set it together with `rootfs`.   |  `None` |
| <a id="firecracker_microvm-rootfs"></a>rootfs |  an ext4 image to boot from. Don't set it together with `initrd`.   |  `None` |
| <a id="firecracker_microvm-extra_drive"></a>extra_drive |  one more writable disk image. It's copied first, so the Bazel output isn't changed. It's `/dev/vda` when booting from an initrd and `/dev/vdb` when booting from a rootfs.   |  `None` |
| <a id="firecracker_microvm-kernel_cmdline"></a>kernel_cmdline |  kernel boot arguments. Default `console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on`.   |  `"console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on"` |
| <a id="firecracker_microvm-vcpus"></a>vcpus |  number of vCPUs.   |  `1` |
| <a id="firecracker_microvm-mem_mib"></a>mem_mib |  guest memory in MiB.   |  `256` |
| <a id="firecracker_microvm-firecracker"></a>firecracker |  the firecracker binary to run. It must be a single executable file. Default `@rules_firecracker//firecracker:firecracker`, the pinned release for the target CPU.   |  `"@@//firecracker:firecracker"` |
| <a id="firecracker_microvm-visibility"></a>visibility |  visibility of the target.   |  `None` |
| <a id="firecracker_microvm-tags"></a>tags |  extra tags. `manual` is always added.   |  `None` |
| <a id="firecracker_microvm-kwargs"></a>kwargs |  passed to the `sh_binary` underneath.   |  none |


<a id="firecracker_renumber_test"></a>

## firecracker_renumber_test

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_renumber_test")

firecracker_renumber_test(<a href="#firecracker_renumber_test-name">name</a>, <a href="#firecracker_renumber_test-vm">vm</a>, <a href="#firecracker_renumber_test-nodes1">nodes1</a>, <a href="#firecracker_renumber_test-nodes2">nodes2</a>, <a href="#firecracker_renumber_test-gw1">gw1</a>, <a href="#firecracker_renumber_test-gw2">gw2</a>, <a href="#firecracker_renumber_test-expect_marker">expect_marker</a>, <a href="#firecracker_renumber_test-timeout1">timeout1</a>, <a href="#firecracker_renumber_test-timeout2">timeout2</a>,
                          <a href="#firecracker_renumber_test-size">size</a>, <a href="#firecracker_renumber_test-visibility">visibility</a>, <a href="#firecracker_renumber_test-tags">tags</a>, <a href="#firecracker_renumber_test-kwargs">**kwargs</a>)
</pre>

Boot a cluster, then reboot it on new IP addresses and check it recovers.

Phase 1 boots `nodes1` on a bridge at `gw1`, the same way
`firecracker_cluster_test` does. Each node gets a 2 GiB ext4 data disk
at `/dev/vdb`, created once per IDX. Phase 2 boots `nodes2` on a bridge
at `gw2` with the same disks, matched by IDX. The test passes if
`expect_marker` appears in a phase 2 console log.

`vm` has to boot from a rootfs, because the data disk only works in that
mode. Tags, SKIP and `FC_NO_SKIP` work the same as in
`firecracker_cluster_test`.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="firecracker_renumber_test-name"></a>name |  name of the test.   |  none |
| <a id="firecracker_renumber_test-vm"></a>vm |  a `firecracker_microvm` that boots from a rootfs.   |  none |
| <a id="firecracker_renumber_test-nodes1"></a>nodes1 |  `"IDX,IP,MAC,EXTRA"` node specs for phase 1.   |  none |
| <a id="firecracker_renumber_test-nodes2"></a>nodes2 |  node specs for phase 2. Same IDXs, new IPs.   |  none |
| <a id="firecracker_renumber_test-gw1"></a>gw1 |  bridge address for phase 1, in CIDR form.   |  none |
| <a id="firecracker_renumber_test-gw2"></a>gw2 |  bridge address for phase 2, in CIDR form.   |  none |
| <a id="firecracker_renumber_test-expect_marker"></a>expect_marker |  must appear in a phase 2 log.   |  none |
| <a id="firecracker_renumber_test-timeout1"></a>timeout1 |  the longest each VM may run in phase 1, in seconds.   |  `240` |
| <a id="firecracker_renumber_test-timeout2"></a>timeout2 |  the longest each VM may run in phase 2, in seconds.   |  `300` |
| <a id="firecracker_renumber_test-size"></a>size |  test size.   |  `"enormous"` |
| <a id="firecracker_renumber_test-visibility"></a>visibility |  visibility of the test.   |  `None` |
| <a id="firecracker_renumber_test-tags"></a>tags |  extra tags.   |  `None` |
| <a id="firecracker_renumber_test-kwargs"></a>kwargs |  passed to the `sh_test` underneath.   |  none |


<a id="firecracker_rootfs"></a>

## firecracker_rootfs

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_rootfs")

firecracker_rootfs(<a href="#firecracker_rootfs-name">name</a>, <a href="#firecracker_rootfs-size_mb">size_mb</a>, <a href="#firecracker_rootfs-label">label</a>, <a href="#firecracker_rootfs-files">files</a>, <a href="#firecracker_rootfs-execs">execs</a>, <a href="#firecracker_rootfs-kwargs">**kwargs</a>)
</pre>

Build an ext4 disk image from a set of files.

It uses `mkfs.ext4 -d`, so it doesn't need root, a mount, or a loop
device. The host needs e2fsprogs 1.43 or newer.

The image holds only the files you list. To boot it as the root
filesystem, install a PID 1 (for example busybox at `/bin/busybox` and a
script at `/sbin/init`) and add `rw init=/sbin/init` to the VM's
`kernel_cmdline`. You can also attach it as a data disk with
`firecracker_microvm(extra_drive = ...)`.

The build step runs locally and the image isn't cached. That's because
the image is a sparse file, and a cache would store it at full size.

The output is `<name>.ext4`.

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
| <a id="firecracker_rootfs-name"></a>name |  target name. The output file is `<name>.ext4`.   |  none |
| <a id="firecracker_rootfs-size_mb"></a>size_mb |  image size in MiB. The file is sparse.   |  none |
| <a id="firecracker_rootfs-label"></a>label |  ext4 volume label, 16 characters at most.   |  none |
| <a id="firecracker_rootfs-files"></a>files |  dict of `{label: absolute_path}`. Installed with mode 0644.   |  `{}` |
| <a id="firecracker_rootfs-execs"></a>execs |  dict of `{label: absolute_path}`. Installed with mode 0755.   |  `{}` |
| <a id="firecracker_rootfs-kwargs"></a>kwargs |  passed to the `genrule` underneath (`visibility`, `tags`, ...).   |  none |


<a id="firecracker_test"></a>

## firecracker_test

<pre>
load("@rules_firecracker//firecracker:defs.bzl", "firecracker_test")

firecracker_test(<a href="#firecracker_test-name">name</a>, <a href="#firecracker_test-microvm">microvm</a>, <a href="#firecracker_test-expect_markers">expect_markers</a>, <a href="#firecracker_test-unexpected_markers">unexpected_markers</a>, <a href="#firecracker_test-timeout_seconds">timeout_seconds</a>, <a href="#firecracker_test-size">size</a>,
                 <a href="#firecracker_test-visibility">visibility</a>, <a href="#firecracker_test-tags">tags</a>, <a href="#firecracker_test-kwargs">**kwargs</a>)
</pre>

A test that boots a VM and checks what it prints on its console.

The test boots the `firecracker_microvm` with
`FC_TIMEOUT=timeout_seconds` and copies the console into the test log.

* Once every `expect_markers` string has appeared, it kills the VM. A
  passing test usually takes a few seconds.
* If they don't all appear, it waits for the VM to exit (for example
  after `reboot -f`) or for the timeout. A timeout on its own doesn't
  fail the test.
* Then it fails if any `expect_markers` string is missing, or if any
  `unexpected_markers` string appears. Matching is plain text, not regex.

It adds the tags `requires-kvm` and `no-cache`. Run it with
`--config=kvm` (see the README) so `/dev/kvm` is in the sandbox.

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
| <a id="firecracker_test-name"></a>name |  name of the test.   |  none |
| <a id="firecracker_test-microvm"></a>microvm |  a `firecracker_microvm` or `firecracker_container`.   |  none |
| <a id="firecracker_test-expect_markers"></a>expect_markers |  strings that must all appear on the console.   |  `[]` |
| <a id="firecracker_test-unexpected_markers"></a>unexpected_markers |  strings that must not appear on the console.   |  `[]` |
| <a id="firecracker_test-timeout_seconds"></a>timeout_seconds |  the longest the VM may run, in seconds.   |  `30` |
| <a id="firecracker_test-size"></a>size |  test size.   |  `"medium"` |
| <a id="firecracker_test-visibility"></a>visibility |  visibility of the test.   |  `None` |
| <a id="firecracker_test-tags"></a>tags |  extra tags. `requires-kvm` and `no-cache` are always added.   |  `None` |
| <a id="firecracker_test-kwargs"></a>kwargs |  passed to the `sh_test` underneath (`timeout`, `flaky`, ...).   |  none |


