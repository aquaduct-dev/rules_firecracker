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
    """Pack a gzip-compressed newc cpio initramfs.

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

    Args:
      name: target name; the output file is `<name>.cpio.gz`.
      init: label of the script or static binary installed at `/init` (PID 1).
      files: dict of `{label: absolute_destination_path}` installed 0644.
      execs: dict of `{label: absolute_destination_path}` installed 0755;
        ELF entries must be statically linked.
      busybox: label of a statically-linked busybox.
        Default `@rules_firecracker//firecracker:busybox_static`.
      **kwargs: forwarded to the underlying `genrule` (`visibility`, `tags`, ...).
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
    """Build an ext4 disk image from a set of files with `mkfs.ext4 -d`.

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

    Args:
      name: target name; the output file is `<name>.ext4`.
      size_mb: image size in MiB (sparse).
      label: ext4 filesystem label (max 16 characters).
      files: dict of `{label: absolute_destination_path}` installed 0644.
      execs: dict of `{label: absolute_destination_path}` installed 0755.
      **kwargs: forwarded to the underlying `genrule` (`visibility`, `tags`, ...).
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
    """A runnable `sh_binary` that boots a firecracker microVM.

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

    Args:
      name: target name of the runnable `sh_binary`.
      kernel: label of an uncompressed x86_64 kernel ELF (`vmlinux`).
        Default `@rules_firecracker//firecracker:vmlinux`.
      initrd: label of a cpio.gz initramfs. Mutually exclusive with `rootfs`.
      rootfs: label of an ext4 root image. Mutually exclusive with `initrd`.
      extra_drive: optional label of a disk image attached as an additional
        writable virtio-block device. It is copied into the temp dir first
        (the bazel output stays immutable): `/dev/vda` in initrd mode,
        `/dev/vdb` in rootfs mode.
      kernel_cmdline: kernel boot arguments. Default
        `console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on`.
      vcpus: number of vCPUs.
      mem_mib: guest memory in MiB.
      firecracker: label of a single executable file: the firecracker VMM to
        run. Default `@rules_firecracker//firecracker:firecracker` (the pinned
        upstream release for the target CPU).
      visibility: visibility of the `sh_binary`.
      tags: extra tags; `manual` is always added.
      **kwargs: forwarded to the `sh_binary`.
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
    """An `sh_test` that boots a microvm and asserts on its serial console.

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

    Args:
      name: target name of the `sh_test`.
      microvm: label of a `firecracker_microvm` (or `firecracker_container`).
      expect_markers: strings that must all appear on the console.
      unexpected_markers: strings that must not appear on the console.
      timeout_seconds: hard cap on VM wall time in seconds.
      size: `sh_test` size.
      visibility: visibility of the `sh_test`.
      tags: extra tags; `requires-kvm` and `no-cache` are always added.
      **kwargs: forwarded to the `sh_test` (e.g. `timeout`, `flaky`).
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
    """Boot a single OCI image as the whole guest: a runnable microvm.

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

    Args:
      name: target name of the runnable microvm.
      image: label of an `oci_image` or any target producing an OCI image
        layout directory (`index.json` + `blobs/sha256/...`).
      size_mb: rootfs size in MiB; must exceed the flattened image.
      kernel: guest kernel. Default `@rules_firecracker//firecracker:vmlinux`.
      extra_env: dict `{KEY: VALUE}` exported after the image `Env`
        (overrides same-named keys).
      extra_args: list of arguments appended after `Entrypoint + Cmd`.
      kernel_cmdline: kernel boot args; includes `init=/sbin/init` so the
        generated init wins over anything the image ships.
      vcpus: number of vCPUs.
      mem_mib: guest memory in MiB.
      busybox: static busybox copied to `/sbin/busybox`.
      firecracker: firecracker VMM binary; see `firecracker_microvm`.
      visibility: visibility of the microvm.
      tags: extra tags for the microvm (`manual` is always added).
      **kwargs: forwarded to `firecracker_microvm`.
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
    """Boot a single-node k3s server in a microVM and run a guest test against it.

    The rootfs (built by `mkk3srootfs`) holds busybox, the static k3s binary
    at `/usr/local/bin/k3s` (`kubectl`, `crictl`, `ctr` symlinks), the test
    binary at `/usr/local/bin/<test_binary name>` and the default PID 1
    (`k3s_init.sh`), which: starts `k3s server` on a dummy interface
    (10.42.0.10, no NIC needed), waits for the node to be Ready, applies
    `/etc/manifests/*.yaml`, then runs

    ```
    <test_binary> --scenario=/etc/manifests/<scenario>.yaml \\
        --report-json=/tmp/report.json \\
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

    Args:
      name: target name of the `sh_test`.
      test_binary: label of a statically-linked guest test binary honoring
        the flags above.
      scenario: scenario name; written to `/etc/scenario` and passed as
        `--scenario=/etc/manifests/<scenario>.yaml`.
      extra_manifests: dict `{label: basename.yaml}` copied to
        `/etc/manifests/` and `kubectl apply`'d once k3s is Ready.
      extra_images: dict `{label: basename.tar}` image tarballs copied to
        `/etc/images/` and preloaded into k3s' containerd (no registry pulls).
      extra_files: dict `{label: absolute_path}` installed 0644.
      extra_execs: dict `{label: absolute_path}` installed 0755.
      timeout_seconds: hard cap on VM wall time.
      vcpus: number of vCPUs (2 is the practical minimum for k3s).
      mem_mib: guest memory in MiB.
      size_mb: rootfs size in MiB.
      kernel: guest kernel. Default `@rules_firecracker//firecracker:vmlinux`.
      kernel_cmdline: kernel boot arguments.
      busybox: static busybox label.
      k3s: static k3s label. Default `@rules_firecracker//firecracker:k3s_binary`.
      init: `/sbin/init` script. Default `@rules_firecracker//firecracker:k3s_init`.
      firecracker: firecracker VMM binary; see `firecracker_microvm`.
      size: `sh_test` size.
      visibility: visibility of the `sh_test`.
      tags: extra tags; `requires-kvm` and `no-cache` are always added.
      **kwargs: forwarded to the `sh_test`.
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
    """Boot N copies of a microvm on a shared host bridge; assert a console marker.

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

    Args:
      name: target name of the `sh_test`.
      vm: label of the `firecracker_microvm` every node boots.
      nodes: list of `"IDX,IP,MAC,EXTRA_CMDLINE"` node specs.
      expect_marker: string that must appear in some node's console log.
      leader_idx: IDX of the node whose log tail is printed for diagnostics.
      subnet_gw: host bridge address in CIDR form; also the guests' gateway.
      timeout_seconds: per-VM hard cap in seconds.
      size: `sh_test` size.
      visibility: visibility of the `sh_test`.
      tags: extra tags (see above for the ones always added).
      **kwargs: forwarded to the `sh_test`.
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
    """Two-phase multi-VM test: boot a cluster, then reboot it on a new subnet.

    Phase 1 boots `nodes1` on a bridge at `gw1`, exactly like
    `firecracker_cluster_test`, with every node given a persistent data disk
    (`FC_PERSIST_DISK`, a 2 GiB ext4 image at `/dev/vdb` in the guest,
    created once per IDX). Phase 2 boots `nodes2` on `gw2` with the SAME
    disks (match nodes by IDX). The test passes iff `expect_marker` appears
    in a phase-2 console log. `vm` must be a rootfs-mode microvm (the
    persistent disk is attached only in rootfs mode).

    Same tags, SKIP and `FC_NO_SKIP` behavior as `firecracker_cluster_test`.

    Args:
      name: target name of the `sh_test`.
      vm: label of a rootfs-mode `firecracker_microvm`.
      nodes1: phase-1 `"IDX,IP,MAC,EXTRA"` node specs.
      nodes2: phase-2 node specs (same IDXs, new IPs).
      gw1: phase-1 bridge address (CIDR).
      gw2: phase-2 bridge address (CIDR).
      expect_marker: string that must appear in a phase-2 log.
      timeout1: phase-1 per-VM cap in seconds.
      timeout2: phase-2 per-VM cap in seconds.
      size: `sh_test` size.
      visibility: visibility of the `sh_test`.
      tags: extra tags.
      **kwargs: forwarded to the `sh_test`.
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
    """Install each node to a GPT disk with an installer, then boot the disks.

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

    Args:
      name: target name of the `sh_test`.
      vm: label of a `firecracker_microvm` (kernel/cmdline/size donor).
      installer: label of the installer executable.
      rootfs: label of the root filesystem image handed to the installer.
      nodes: `"IDX,IP,MAC,EXTRA"` node specs.
      expect_marker: string that must appear in a phase-2 log.
      gw: bridge address (CIDR).
      secret: value written to `cluster_secret` in each settings.ini.
      timeout_seconds: per-VM cap in seconds for phase 2.
      size: `sh_test` size.
      visibility: visibility of the `sh_test`.
      tags: extra tags.
      **kwargs: forwarded to the `sh_test`.
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
