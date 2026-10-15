"""Implementation of the rules_firecracker macros.

Not public API: load the macros from `@rules_firecracker//firecracker:defs.bzl`.
"""

load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

_DEFAULT_BUSYBOX = str(Label("//firecracker:busybox_static"))
_DEFAULT_KERNEL = str(Label("//firecracker:vmlinux"))
_DEFAULT_K3S = str(Label("//firecracker:k3s_binary"))
_DEFAULT_FIRECRACKER = str(Label("//firecracker:firecracker"))
_JQ = str(Label("//firecracker:jq"))
_MKINITRAMFS = str(Label("//firecracker:mkinitramfs"))
_MKROOTFS = str(Label("//firecracker:mkrootfs"))
_MKCONTAINERFS = str(Label("//firecracker:mkcontainerfs"))
_MKK3SROOTFS = str(Label("//firecracker:mkk3srootfs"))
_GEN_TEST = str(Label("//firecracker:gen_test"))
_GEN_K3S_TEST = str(Label("//firecracker:gen_k3s_test"))
_K3S_INIT = str(Label("//firecracker:k3s_init"))
_RUNNER_TPL = str(Label("//firecracker/private:runner.sh.tpl"))
_CLUSTER_RUN = str(Label("//firecracker/private:cluster_run.sh"))
_CLUSTER_TEST_TPL = str(Label("//firecracker/private:cluster_test.sh.tpl"))
_RENUMBER_TEST_TPL = str(Label("//firecracker/private:cluster_renumber_test.sh.tpl"))
_INSTALL_TEST_TPL = str(Label("//firecracker/private:cluster_install_test.sh.tpl"))
_RUNFILES_LIB = "@bazel_tools//tools/bash/runfiles"

# `random.trust_cpu=on` lets the kernel seed its RNG from RDRAND so Go's
# crypto/rand doesn't block ~60s waiting for entropy.
DEFAULT_KERNEL_CMDLINE = "console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on"

# Tags every multi-VM rig gets: it needs the host network namespace and
# passwordless sudo for bridge/TAP setup, so it can't be sandboxed.
_CLUSTER_TAGS = ["requires-kvm", "no-cache", "local", "no-sandbox", "manual"]

def _shell_quote(s):
    # Single-quote for sed/shell embedding. Replace ' with '\''.
    return "'" + s.replace("'", "'\\''") + "'"

def _uniq(labels):
    # A label may legitimately appear twice (e.g. busybox also listed in
    # `execs`); genrule srcs/data reject duplicates.
    out = []
    seen = {}
    for l in labels:
        key = str(native.package_relative_label(l))
        if key not in seen:
            seen[key] = True
            out.append(l)
    return out

def _rlocation_path(label):
    # rlocation path of an executable target: <canonical repo>/<pkg>/<name>,
    # where the root module's repo is `_main`. $(rlocationpath) can't be used
    # for an sh_binary (it expands to more than one file), so compute it from
    # the label at macro-expansion time.
    abs = native.package_relative_label(label)
    repo = abs.repo_name or "_main"
    if abs.package:
        return "{}/{}/{}".format(repo, abs.package, abs.name)
    return "{}/{}".format(repo, abs.name)

def firecracker_initramfs(
        name,
        init,
        files = {},
        execs = {},
        busybox = _DEFAULT_BUSYBOX,
        **kwargs):
    """Pack files into an initramfs (a gzip-compressed cpio archive).

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

    Args:
      name: target name. The output file is `<name>.cpio.gz`.
      init: script or static binary to run as PID 1. Installed at `/init`.
      files: dict of `{label: absolute_path}`. Installed with mode 0644.
      execs: dict of `{label: absolute_path}`. Installed with mode 0755.
        ELF files must be statically linked.
      busybox: a static busybox.
        Default `@rules_firecracker//firecracker:busybox_static`.
      **kwargs: passed to the `genrule` underneath (`visibility`, `tags`, ...).
    """
    srcs = [init, busybox] + list(files.keys()) + list(execs.keys())
    args = [
        "--out '$@'",
        "--busybox $(execpath {})".format(busybox),
        "--init $(execpath {})".format(init),
    ]
    for src, dst in files.items():
        args.append("--file \"$(execpath {})={}\"".format(src, dst))
    for src, dst in execs.items():
        args.append("--exec \"$(execpath {})={}\"".format(src, dst))

    native.genrule(
        name = name,
        srcs = _uniq(srcs),
        outs = [name + ".cpio.gz"],
        cmd = "$(execpath {tool}) {args}".format(
            tool = _MKINITRAMFS,
            args = " ".join(args),
        ),
        tools = [_MKINITRAMFS],
        **kwargs
    )

def firecracker_rootfs(
        name,
        size_mb,
        label,
        files = {},
        execs = {},
        **kwargs):
    """Build an ext4 disk image from a set of files.

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

    Args:
      name: target name. The output file is `<name>.ext4`.
      size_mb: image size in MiB. The file is sparse.
      label: ext4 volume label, 16 characters at most.
      files: dict of `{label: absolute_path}`. Installed with mode 0644.
      execs: dict of `{label: absolute_path}`. Installed with mode 0755.
      **kwargs: passed to the `genrule` underneath (`visibility`, `tags`, ...).
    """
    srcs = list(files.keys()) + list(execs.keys())
    args = [
        "--out '$@'",
        "--size-mb {}".format(size_mb),
        "--label {}".format(label),
    ]
    for src, dst in files.items():
        args.append("--file \"$(execpath {})={}\"".format(src, dst))
    for src, dst in execs.items():
        args.append("--exec \"$(execpath {})={}\"".format(src, dst))

    native.genrule(
        name = name,
        srcs = _uniq(srcs),
        outs = [name + ".ext4"],
        cmd = "$(execpath {tool}) {args}".format(
            tool = _MKROOTFS,
            args = " ".join(args),
        ),
        tools = [_MKROOTFS],
        local = True,
        **kwargs
    )

def firecracker_microvm(
        name,
        kernel = _DEFAULT_KERNEL,
        initrd = None,
        rootfs = None,
        extra_drive = None,
        kernel_cmdline = DEFAULT_KERNEL_CMDLINE,
        vcpus = 1,
        mem_mib = 256,
        firecracker = _DEFAULT_FIRECRACKER,
        visibility = None,
        tags = None,
        **kwargs):
    """Create a target you can `bazel run` to boot a VM.

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

    Args:
      name: name of the target you run.
      kernel: an uncompressed x86_64 kernel ELF (`vmlinux`).
        Default `@rules_firecracker//firecracker:vmlinux`.
      initrd: an initramfs to boot from. Don't set it together with `rootfs`.
      rootfs: an ext4 image to boot from. Don't set it together with
        `initrd`.
      extra_drive: one more writable disk image. It's copied first, so the
        Bazel output isn't changed. It's `/dev/vda` when booting from an
        initrd and `/dev/vdb` when booting from a rootfs.
      kernel_cmdline: kernel boot arguments. Default
        `console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on`.
      vcpus: number of vCPUs.
      mem_mib: guest memory in MiB.
      firecracker: the firecracker binary to run. It must be a single
        executable file. Default `@rules_firecracker//firecracker:firecracker`,
        the pinned release for the target CPU.
      visibility: visibility of the target.
      tags: extra tags. `manual` is always added.
      **kwargs: passed to the `sh_binary` underneath.
    """
    if (initrd == None) == (rootfs == None):
        fail("firecracker_microvm: exactly one of `initrd` or `rootfs` required")

    boot_label = initrd if initrd != None else rootfs
    boot_kind = "initrd" if initrd != None else "rootfs"
    runner_src = "_" + name + "__runner.sh"

    srcs = [kernel, boot_label, firecracker, _RUNNER_TPL]
    data = [kernel, boot_label, firecracker]
    if extra_drive != None:
        srcs.append(extra_drive)
        data.append(extra_drive)
        extra_drive_rloc_expr = "$(rlocationpath {})".format(extra_drive)
    else:
        extra_drive_rloc_expr = ""

    native.genrule(
        name = name + "__gen_runner",
        srcs = _uniq(srcs),
        outs = [runner_src],
        cmd = (
            "sed " +
            "-e 's|@@KERNEL_RLOC@@|$(rlocationpath {kernel})|g' " +
            "-e 's|@@BOOT_RLOC@@|$(rlocationpath {boot})|g' " +
            "-e 's|@@FIRECRACKER_RLOC@@|$(rlocationpath {fc})|g' " +
            "-e 's|@@BOOT_KIND@@|{kind}|g' " +
            "-e 's|@@EXTRA_DRIVE_RLOC@@|{extra}|g' " +
            "-e 's|@@KERNEL_CMDLINE@@|{cmdline}|g' " +
            "-e 's|@@VCPUS@@|{vcpus}|g' " +
            "-e 's|@@MEM_MIB@@|{mem_mib}|g' " +
            "$(execpath {tpl}) > $@ && chmod +x $@"
        ).format(
            kernel = kernel,
            boot = boot_label,
            fc = firecracker,
            kind = boot_kind,
            extra = extra_drive_rloc_expr,
            cmdline = kernel_cmdline,
            vcpus = vcpus,
            mem_mib = mem_mib,
            tpl = _RUNNER_TPL,
        ),
        tags = ["manual"],
        visibility = ["//visibility:private"],
    )

    sh_binary(
        name = name,
        srcs = [runner_src],
        data = _uniq(data),
        deps = [_RUNFILES_LIB],
        visibility = visibility,
        tags = (tags or []) + ["manual"],
        **kwargs
    )

def firecracker_test(
        name,
        microvm,
        expect_markers = [],
        unexpected_markers = [],
        timeout_seconds = 30,
        size = "medium",
        visibility = None,
        tags = None,
        **kwargs):
    """A test that boots a VM and checks what it prints on its console.

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

    Args:
      name: name of the test.
      microvm: a `firecracker_microvm` or `firecracker_container`.
      expect_markers: strings that must all appear on the console.
      unexpected_markers: strings that must not appear on the console.
      timeout_seconds: the longest the VM may run, in seconds.
      size: test size.
      visibility: visibility of the test.
      tags: extra tags. `requires-kvm` and `no-cache` are always added.
      **kwargs: passed to the `sh_test` underneath (`timeout`, `flaky`, ...).
    """
    test_src = "_" + name + "__test.sh"

    args = [
        "--out '$@'",
        "--runner-rloc {}".format(_rlocation_path(microvm)),
        "--timeout {}".format(timeout_seconds),
    ]
    for m in expect_markers:
        args.append("--expect {}".format(_shell_quote(m)))
    for m in unexpected_markers:
        args.append("--unexpect {}".format(_shell_quote(m)))

    native.genrule(
        name = name + "__gen_test",
        srcs = [microvm],
        outs = [test_src],
        cmd = "$(execpath {tool}) {args}".format(
            tool = _GEN_TEST,
            args = " ".join(args),
        ),
        tools = [_GEN_TEST],
        tags = ["manual"],
        visibility = ["//visibility:private"],
    )

    sh_test(
        name = name,
        srcs = [test_src],
        data = [microvm],
        deps = [_RUNFILES_LIB],
        size = size,
        visibility = visibility,
        tags = (tags or []) + ["requires-kvm", "no-cache"],
        **kwargs
    )

def firecracker_container(
        name,
        image,
        size_mb = 512,
        kernel = _DEFAULT_KERNEL,
        extra_env = {},
        extra_args = [],
        kernel_cmdline = DEFAULT_KERNEL_CMDLINE + " init=/sbin/init",
        vcpus = 1,
        mem_mib = 512,
        busybox = _DEFAULT_BUSYBOX,
        firecracker = _DEFAULT_FIRECRACKER,
        visibility = None,
        tags = None,
        **kwargs):
    """Boot one OCI image as the whole VM.

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

    Args:
      name: name of the VM target.
      image: an `oci_image`, or any target that produces an OCI image layout
        directory (`index.json` and `blobs/sha256/...`).
      size_mb: root filesystem size in MiB. It must be bigger than the
        merged image.
      kernel: guest kernel. Default `@rules_firecracker//firecracker:vmlinux`.
      extra_env: dict of `{KEY: VALUE}`. Set after the image's `Env`, so
        these win.
      extra_args: arguments added after `Entrypoint + Cmd`.
      kernel_cmdline: kernel boot arguments. The default includes
        `init=/sbin/init` so the generated init runs, not one from the image.
      vcpus: number of vCPUs.
      mem_mib: guest memory in MiB.
      busybox: static busybox, copied to `/sbin/busybox`.
      firecracker: the firecracker binary. See `firecracker_microvm`.
      visibility: visibility of the VM target.
      tags: extra tags for the VM target. `manual` is always added.
      **kwargs: passed to `firecracker_microvm`.
    """
    rootfs_name = "_" + name + "__rootfs"

    args = [
        "--out '$@'",
        "--image-dir '$(execpath {})'".format(image),
        "--busybox '$(execpath {})'".format(busybox),
        "--size-mb {}".format(size_mb),
        "--label container",
    ]
    for k, v in extra_env.items():
        args.append("--extra-env {}".format(_shell_quote("{}={}".format(k, v))))
    for a in extra_args:
        args.append("--extra-arg {}".format(_shell_quote(a)))

    native.genrule(
        name = rootfs_name,
        srcs = [image, busybox],
        outs = [rootfs_name + ".ext4"],
        cmd = "$(execpath {tool}) {args}".format(
            tool = _MKCONTAINERFS,
            args = " ".join(args),
        ),
        tools = [_MKCONTAINERFS],
        local = True,
        tags = ["manual"],
        visibility = ["//visibility:private"],
    )

    firecracker_microvm(
        name = name,
        kernel = kernel,
        rootfs = ":" + rootfs_name,
        kernel_cmdline = kernel_cmdline,
        vcpus = vcpus,
        mem_mib = mem_mib,
        firecracker = firecracker,
        visibility = visibility,
        tags = tags,
        **kwargs
    )

def firecracker_k3s_test(
        name,
        test_binary,
        scenario,
        extra_manifests = {},
        extra_images = {},
        extra_files = {},
        extra_execs = {},
        timeout_seconds = 300,
        vcpus = 2,
        mem_mib = 2048,
        size_mb = 2048,
        kernel = _DEFAULT_KERNEL,
        kernel_cmdline = DEFAULT_KERNEL_CMDLINE,
        busybox = _DEFAULT_BUSYBOX,
        k3s = _DEFAULT_K3S,
        init = _K3S_INIT,
        firecracker = _DEFAULT_FIRECRACKER,
        size = "enormous",
        visibility = None,
        tags = None,
        **kwargs):
    """Start k3s in a VM and run your test program against it.

    The VM's disk is built by `mkk3srootfs`. It holds busybox, k3s at
    `/usr/local/bin/k3s` (with `kubectl`, `crictl` and `ctr` links), your
    test program at `/usr/local/bin/<its target name>`, and the init script.

    The init script (`k3s_init.sh` by default) starts `k3s server` on a
    dummy interface at 10.42.0.10, so the VM needs no network card. It waits
    for the node to be ready, applies `/etc/manifests/*.yaml`, and runs

    ```
    <test_binary> --scenario=/etc/manifests/<scenario>.yaml \\
        --report-json=/tmp/report.json \\
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

    Args:
      name: name of the test.
      test_binary: your test program. It must be statically linked and
        accept the flags above.
      scenario: a scenario name. It's written to `/etc/scenario` and passed
        as `--scenario=/etc/manifests/<scenario>.yaml`.
      extra_manifests: dict of `{label: file_name.yaml}`. Copied into
        `/etc/manifests/` and applied with `kubectl apply` once k3s is ready.
      extra_images: dict of `{label: file_name.tar}`. Image tarballs, copied
        into `/etc/images/` and loaded into k3s, so nothing is pulled from a
        registry.
      extra_files: dict of `{label: absolute_path}`. Installed with mode 0644.
      extra_execs: dict of `{label: absolute_path}`. Installed with mode 0755.
      timeout_seconds: the longest the VM may run, in seconds.
      vcpus: number of vCPUs. k3s needs at least 2.
      mem_mib: guest memory in MiB.
      size_mb: disk size in MiB.
      kernel: guest kernel. Default `@rules_firecracker//firecracker:vmlinux`.
      kernel_cmdline: kernel boot arguments.
      busybox: static busybox.
      k3s: static k3s. Default `@rules_firecracker//firecracker:k3s_binary`.
      init: the init script, installed at `/sbin/init`.
        Default `@rules_firecracker//firecracker:k3s_init`.
      firecracker: the firecracker binary. See `firecracker_microvm`.
      size: test size.
      visibility: visibility of the test.
      tags: extra tags. `requires-kvm` and `no-cache` are always added.
      **kwargs: passed to the `sh_test` underneath.
    """
    rootfs_name = "_" + name + "__rootfs"
    microvm_name = "_" + name + "__microvm"
    test_src = "_" + name + "__test.sh"

    test_basename = native.package_relative_label(test_binary).name

    args = [
        "--out '$@'",
        "--busybox '$(execpath {})'".format(busybox),
        "--k3s '$(execpath {})'".format(k3s),
        "--init '$(execpath {})'".format(init),
        "--test-binary '$(execpath {})'".format(test_binary),
        "--test-binary-name {}".format(_shell_quote(test_basename)),
        "--scenario {}".format(_shell_quote(scenario)),
        "--size-mb {}".format(size_mb),
        "--label k3s",
    ]
    srcs = [busybox, k3s, init, test_binary]
    for label, dst in extra_manifests.items():
        args.append("--manifest \"$(execpath {})={}\"".format(label, dst))
        srcs.append(label)
    for label, dst in extra_images.items():
        args.append("--image \"$(execpath {})={}\"".format(label, dst))
        srcs.append(label)
    for label, dst in extra_files.items():
        args.append("--file \"$(execpath {})={}\"".format(label, dst))
        srcs.append(label)
    for label, dst in extra_execs.items():
        args.append("--exec \"$(execpath {})={}\"".format(label, dst))
        srcs.append(label)

    native.genrule(
        name = rootfs_name,
        srcs = _uniq(srcs),
        outs = [rootfs_name + ".ext4"],
        cmd = "$(execpath {tool}) {args}".format(
            tool = _MKK3SROOTFS,
            args = " ".join(args),
        ),
        tools = [_MKK3SROOTFS],
        local = True,
        tags = ["manual"],
        visibility = ["//visibility:private"],
    )

    firecracker_microvm(
        name = microvm_name,
        kernel = kernel,
        rootfs = ":" + rootfs_name,
        kernel_cmdline = kernel_cmdline,
        vcpus = vcpus,
        mem_mib = mem_mib,
        firecracker = firecracker,
        tags = ["manual"],
    )

    gen_args = [
        "--out '$@'",
        "--runner-rloc {}".format(_rlocation_path(":" + microvm_name)),
        "--jq-rloc $(rlocationpath {})".format(_JQ),
        "--timeout {}".format(timeout_seconds),
    ]

    native.genrule(
        name = name + "__gen_test",
        srcs = [":" + microvm_name, _JQ],
        outs = [test_src],
        cmd = "$(execpath {tool}) {args}".format(
            tool = _GEN_K3S_TEST,
            args = " ".join(gen_args),
        ),
        tools = [_GEN_K3S_TEST],
        tags = ["manual"],
        visibility = ["//visibility:private"],
    )

    sh_test(
        name = name,
        srcs = [test_src],
        data = [":" + microvm_name, _JQ],
        deps = [_RUNFILES_LIB],
        size = size,
        visibility = visibility,
        tags = (tags or []) + ["requires-kvm", "no-cache"],
        **kwargs
    )

def firecracker_cluster_test(
        name,
        vm,
        nodes,
        expect_marker,
        leader_idx,
        subnet_gw = "10.211.55.1/24",
        timeout_seconds = 360,
        size = "enormous",
        visibility = None,
        tags = None,
        **kwargs):
    """Boot several copies of one VM on a shared network and check their logs.

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

    Args:
      name: name of the test.
      vm: the `firecracker_microvm` every node boots.
      nodes: one `"IDX,IP,MAC,EXTRA"` string per node.
      expect_marker: must appear in at least one node's console log.
      leader_idx: IDX of the node whose log is printed at the end.
      subnet_gw: the bridge address in CIDR form. It's also the VMs' gateway.
      timeout_seconds: the longest each VM may run, in seconds.
      size: test size.
      visibility: visibility of the test.
      tags: extra tags. The tags listed above are always added.
      **kwargs: passed to the `sh_test` underneath.
    """
    test_src = "_" + name + "__cluster_test.sh"

    native.genrule(
        name = name + "__gen",
        srcs = [_CLUSTER_TEST_TPL, _CLUSTER_RUN],
        outs = [test_src],
        cmd = (
            "sed " +
            "-e 's|@@RUNNER_RLOC@@|{vm_rloc}|g' " +
            "-e 's|@@CLUSTER_RUN_RLOC@@|$(rlocationpath {crun})|g' " +
            "-e 's|@@NODES@@|{nodes}|g' " +
            "-e 's|@@SUBNET_GW@@|{gw}|g' " +
            "-e 's|@@TIMEOUT@@|{timeout}|g' " +
            "-e 's|@@LEADER_IDX@@|{leader}|g' " +
            "-e 's|@@EXPECT_MARKER@@|{marker}|g' " +
            "$(execpath {tpl}) > $@ && chmod +x $@"
        ).format(
            vm_rloc = _rlocation_path(vm),
            crun = _CLUSTER_RUN,
            nodes = ";".join(nodes),
            gw = subnet_gw,
            timeout = timeout_seconds,
            leader = leader_idx,
            marker = expect_marker,
            tpl = _CLUSTER_TEST_TPL,
        ),
        tags = ["manual"],
        visibility = ["//visibility:private"],
    )

    sh_test(
        name = name,
        srcs = [test_src],
        data = [vm, _CLUSTER_RUN],
        deps = [_RUNFILES_LIB],
        size = size,
        visibility = visibility,
        tags = (tags or []) + _CLUSTER_TAGS,
        **kwargs
    )

def firecracker_renumber_test(
        name,
        vm,
        nodes1,
        nodes2,
        gw1,
        gw2,
        expect_marker,
        timeout1 = 240,
        timeout2 = 300,
        size = "enormous",
        visibility = None,
        tags = None,
        **kwargs):
    """Boot a cluster, then reboot it on new IP addresses and check it recovers.

    Phase 1 boots `nodes1` on a bridge at `gw1`, the same way
    `firecracker_cluster_test` does. Each node gets a 2 GiB ext4 data disk
    at `/dev/vdb`, created once per IDX. Phase 2 boots `nodes2` on a bridge
    at `gw2` with the same disks, matched by IDX. The test passes if
    `expect_marker` appears in a phase 2 console log.

    `vm` has to boot from a rootfs, because the data disk only works in that
    mode. Tags, SKIP and `FC_NO_SKIP` work the same as in
    `firecracker_cluster_test`.

    Args:
      name: name of the test.
      vm: a `firecracker_microvm` that boots from a rootfs.
      nodes1: `"IDX,IP,MAC,EXTRA"` node specs for phase 1.
      nodes2: node specs for phase 2. Same IDXs, new IPs.
      gw1: bridge address for phase 1, in CIDR form.
      gw2: bridge address for phase 2, in CIDR form.
      expect_marker: must appear in a phase 2 log.
      timeout1: the longest each VM may run in phase 1, in seconds.
      timeout2: the longest each VM may run in phase 2, in seconds.
      size: test size.
      visibility: visibility of the test.
      tags: extra tags.
      **kwargs: passed to the `sh_test` underneath.
    """
    test_src = "_" + name + "__renumber_test.sh"

    native.genrule(
        name = name + "__gen",
        srcs = [_RENUMBER_TEST_TPL, _CLUSTER_RUN],
        outs = [test_src],
        cmd = (
            "sed " +
            "-e 's|@@RUNNER_RLOC@@|{vm_rloc}|g' " +
            "-e 's|@@CLUSTER_RUN_RLOC@@|$(rlocationpath {crun})|g' " +
            "-e 's|@@NODES1@@|{nodes1}|g' " +
            "-e 's|@@NODES2@@|{nodes2}|g' " +
            "-e 's|@@GW1@@|{gw1}|g' -e 's|@@GW2@@|{gw2}|g' " +
            "-e 's|@@TIMEOUT1@@|{t1}|g' -e 's|@@TIMEOUT2@@|{t2}|g' " +
            "-e 's|@@EXPECT_MARKER@@|{marker}|g' " +
            "$(execpath {tpl}) > $@ && chmod +x $@"
        ).format(
            vm_rloc = _rlocation_path(vm),
            crun = _CLUSTER_RUN,
            nodes1 = ";".join(nodes1),
            nodes2 = ";".join(nodes2),
            gw1 = gw1,
            gw2 = gw2,
            t1 = timeout1,
            t2 = timeout2,
            marker = expect_marker,
            tpl = _RENUMBER_TEST_TPL,
        ),
        tags = ["manual"],
        visibility = ["//visibility:private"],
    )

    sh_test(
        name = name,
        srcs = [test_src],
        data = [vm, _CLUSTER_RUN],
        deps = [_RUNFILES_LIB],
        size = size,
        visibility = visibility,
        tags = (tags or []) + _CLUSTER_TAGS,
        **kwargs
    )

def firecracker_install_cluster_test(
        name,
        vm,
        installer,
        rootfs,
        nodes,
        expect_marker,
        gw = "10.211.55.1/24",
        secret = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        timeout_seconds = 360,
        size = "enormous",
        visibility = None,
        tags = None,
        **kwargs):
    """Install each node to a blank disk, then boot the cluster from the disks.

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

    Args:
      name: name of the test.
      vm: a `firecracker_microvm` to take the kernel, command line and size
        from.
      installer: your installer program.
      rootfs: the root filesystem image passed to the installer.
      nodes: `"IDX,IP,MAC,EXTRA"` node specs.
      expect_marker: must appear in a phase 2 log.
      gw: bridge address in CIDR form.
      secret: written as `cluster_secret` in each `settings.ini`.
      timeout_seconds: the longest each VM may run in phase 2, in seconds.
      size: test size.
      visibility: visibility of the test.
      tags: extra tags.
      **kwargs: passed to the `sh_test` underneath.
    """
    test_src = "_" + name + "__install_test.sh"
    inst_label = native.package_relative_label(installer)

    # go_binary puts its executable at <pkg>/<name>_/<name>; other rules at
    # <pkg>/<name>. The template takes the first candidate that exists.
    inst_rloc = _rlocation_path(installer)
    inst_rlocs = "{}_/{} {}".format(inst_rloc, inst_label.name, inst_rloc)
    idxs = " ".join([spec.split(",")[0] for spec in nodes])

    native.genrule(
        name = name + "__gen",
        srcs = [_INSTALL_TEST_TPL, _CLUSTER_RUN, rootfs],
        outs = [test_src],
        cmd = (
            "sed " +
            "-e 's|@@RUNNER_RLOC@@|{vm_rloc}|g' " +
            "-e 's|@@INSTALLER_RLOCS@@|{inst_rlocs}|g' " +
            "-e 's|@@CLUSTER_RUN_RLOC@@|$(rlocationpath {crun})|g' " +
            "-e 's|@@ROOTFS_RLOC@@|$(rlocationpath {rootfs})|g' " +
            "-e 's|@@NODES@@|{nodes}|g' -e 's|@@IDXS@@|{idxs}|g' " +
            "-e 's|@@GW@@|{gw}|g' -e 's|@@TIMEOUT@@|{tmo}|g' " +
            "-e 's|@@SECRET@@|{secret}|g' -e 's|@@EXPECT_MARKER@@|{marker}|g' " +
            "$(execpath {tpl}) > $@ && chmod +x $@"
        ).format(
            vm_rloc = _rlocation_path(vm),
            inst_rlocs = inst_rlocs,
            crun = _CLUSTER_RUN,
            rootfs = rootfs,
            nodes = ";".join(nodes),
            idxs = idxs,
            gw = gw,
            tmo = timeout_seconds,
            secret = secret,
            marker = expect_marker,
            tpl = _INSTALL_TEST_TPL,
        ),
        tags = ["manual"],
        visibility = ["//visibility:private"],
    )

    sh_test(
        name = name,
        srcs = [test_src],
        data = [vm, installer, rootfs, _CLUSTER_RUN],
        deps = [_RUNFILES_LIB],
        size = size,
        visibility = visibility,
        tags = (tags or []) + _CLUSTER_TAGS,
        **kwargs
    )
