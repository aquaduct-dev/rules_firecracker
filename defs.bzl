"""Bazel macros for building and testing Firecracker microVMs.

Public API:

  firecracker_initramfs(name, init, files = {}, execs = {}, busybox = ...)
      Pack a cpio+gzip initramfs. `init` is the script installed at /init
      (PID 1). `files` and `execs` are {label: dst_path} maps for regular
      and executable files respectively; ELF entries in `execs` are
      checked for static linkage at build time. Busybox applets are
      auto-symlinked into /bin (and a few into /sbin).

  firecracker_rootfs(name, size_mb, label, files = {}, execs = {})
      Build an ext4 disk image via `mkfs.ext4 -d`. Output: <name>.ext4.
      Requires e2fsprogs >=1.43 on the host (Debian 10+).

  firecracker_microvm(name, kernel, initrd | rootfs, kernel_cmdline,
                      vcpus, mem_mib)
      Emit a runnable sh_binary that boots the VM under host firecracker.
      Exactly one of `initrd` or `rootfs` must be set.

  firecracker_test(name, microvm, expect_markers, unexpected_markers,
                   timeout_seconds)
      sh_test that boots a `firecracker_microvm` for `timeout_seconds`,
      tees serial-console output, then asserts every `expect_markers`
      string is present and every `unexpected_markers` string is absent.
      Tagged `requires-kvm` and `no-cache`. Run with `--config=kvm`
      (defined in //.bazelrc) to bind-mount /dev/kvm into the sandbox.
      The VM is killed as soon as every expect_marker has appeared, so
      typical tests finish in a few seconds regardless of timeout_seconds.

  firecracker_container(name, image, size_mb, kernel, extra_env, extra_args,
                        kernel_cmdline, vcpus, mem_mib, busybox)
      Boot a single OCI image (`rules_oci` oci_image label) inside a
      microVM. The image's flattened filesystem becomes the rootfs and
      a generated /sbin/init mounts /proc /sys /dev, exports the image's
      Env (plus `extra_env`), cd's to WorkingDir, then runs the image's
      Entrypoint+Cmd (plus `extra_args`). On exit, init poweroffs the
      VM cleanly. The macro expands to a runnable `firecracker_microvm`
      named `<name>`. Useful for booting kubernetes node images or
      single-container workloads under VM isolation.
"""

load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

_DEFAULT_BUSYBOX = "//tools/firecracker:busybox_static"
_DEFAULT_KERNEL = "//tools/firecracker:vmlinux"
_MKINITRAMFS = "//tools/firecracker:mkinitramfs"
_MKROOTFS = "//tools/firecracker:mkrootfs"
_MKCONTAINERFS = "//tools/firecracker:mkcontainerfs"
_GEN_TEST = "//tools/firecracker:gen_test"
_RUNNER_TPL = "//tools/firecracker:runner.sh.tpl"

# `random.trust_cpu=on` lets the kernel seed its RNG from RDRAND so
# Go's crypto/rand doesn't block ~60s waiting for entropy. Pinned
# kernel (vmlinux-6.1.102) honors the arg.
_DEFAULT_CMDLINE = "console=ttyS0 reboot=k panic=1 pci=off random.trust_cpu=on"

def _shell_quote(s):
    # Single-quote for sed/shell embedding. Replace ' with '\''.
    return "'" + s.replace("'", "'\\''") + "'"

def _rlocation_path(label):
    # rlocation paths under bzlmod for the root module are _main/<pkg>/<name>.
    # Used to address a sh_binary's launcher script from a sibling sh_test —
    # $(rlocationpath label) would expand to multiple files (the runner script
    # plus the binary itself), so we compute it ourselves at macro-expansion
    # time. Verified by inspecting smoke_vm.runfiles/.
    abs = native.package_relative_label(label)
    if abs.package:
        return "_main/{}/{}".format(abs.package, abs.name)
    return "_main/{}".format(abs.name)

def firecracker_initramfs(
        name,
        init,
        files = {},
        execs = {},
        busybox = _DEFAULT_BUSYBOX,
        **kwargs):
    """Pack a cpio+gzip initramfs from a set of files.

    Args:
      name: target name; output is <name>.cpio.gz.
      init: label installed at /init (PID 1).
      files: {label: dst_path} regular files (0644).
      execs: {label: dst_path} executable files (0755). ELF entries are
        checked for static linkage at build time.
      busybox: label to a statically-linked busybox binary.
      **kwargs: forwarded to the underlying genrule (visibility, tags...).
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
        srcs = srcs,
        outs = [name + ".cpio.gz"],
        cmd = "$(execpath {tool}) {args}".format(
            tool = _MKINITRAMFS,
            args = " ".join(args),
        ),
        tools = [_MKINITRAMFS],
        # Host busybox + cpio + gzip; not hermetic.
        local = True,
        **kwargs
    )

def firecracker_rootfs(
        name,
        size_mb,
        label,
        files = {},
        execs = {},
        **kwargs):
    """Build an ext4 disk image with `mkfs.ext4 -d`.

    Args:
      name: target name; output is <name>.ext4.
      size_mb: image size in megabytes.
      label: filesystem label (max 16 chars).
      files: {label: dst_path} regular files (0644).
      execs: {label: dst_path} executable files (0755).
      **kwargs: forwarded to the underlying genrule (visibility, tags...).
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
        srcs = srcs,
        outs = [name + ".ext4"],
        cmd = "$(execpath {tool}) {args}".format(
            tool = _MKROOTFS,
            args = " ".join(args),
        ),
        tools = [_MKROOTFS],
        # Host mkfs.ext4 (e2fsprogs).
        local = True,
        **kwargs
    )

def firecracker_microvm(
        name,
        kernel,
        initrd = None,
        rootfs = None,
        kernel_cmdline = _DEFAULT_CMDLINE,
        vcpus = 1,
        mem_mib = 256,
        visibility = None,
        tags = None,
        **kwargs):
    """Emit a runnable sh_binary that boots a firecracker microVM.

    Args:
      name: target name; sh_binary label.
      kernel: label of an uncompressed kernel ELF.
      initrd: label of a cpio.gz initramfs (mutually exclusive with rootfs).
      rootfs: label of an ext4 disk image (mutually exclusive with initrd).
      kernel_cmdline: boot args passed to the kernel.
      vcpus: vCPU count.
      mem_mib: guest memory in MiB.
      visibility: target visibility.
      tags: target tags. The macro auto-adds `manual`.
      **kwargs: forwarded to sh_binary.
    """
    if (initrd == None) == (rootfs == None):
        fail("firecracker_microvm: exactly one of `initrd` or `rootfs` required")

    boot_label = initrd if initrd != None else rootfs
    boot_kind = "initrd" if initrd != None else "rootfs"
    runner_src = "_" + name + "__runner.sh"

    native.genrule(
        name = name + "__gen_runner",
        srcs = [kernel, boot_label, _RUNNER_TPL],
        outs = [runner_src],
        cmd = (
            "sed " +
            "-e 's|@@KERNEL_RLOC@@|$(rlocationpath {kernel})|g' " +
            "-e 's|@@BOOT_RLOC@@|$(rlocationpath {boot})|g' " +
            "-e 's|@@BOOT_KIND@@|{kind}|g' " +
            "-e 's|@@KERNEL_CMDLINE@@|{cmdline}|g' " +
            "-e 's|@@VCPUS@@|{vcpus}|g' " +
            "-e 's|@@MEM_MIB@@|{mem_mib}|g' " +
            "$(execpath {tpl}) > $@ && chmod +x $@"
        ).format(
            kernel = kernel,
            boot = boot_label,
            kind = boot_kind,
            cmdline = kernel_cmdline,
            vcpus = vcpus,
            mem_mib = mem_mib,
            tpl = _RUNNER_TPL,
        ),
        tags = ["manual"],
    )

    sh_binary(
        name = name,
        srcs = [runner_src],
        data = [kernel, boot_label],
        deps = ["@bazel_tools//tools/bash/runfiles"],
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
    """sh_test that boots a microvm and asserts on serial-console output.

    Args:
      name: target name; sh_test label.
      microvm: label of a firecracker_microvm.
      expect_markers: substrings that must appear in the boot log
        (fixed-string `grep -F`).
      unexpected_markers: substrings that must NOT appear in the boot log.
      timeout_seconds: how long the VM is allowed to run before the host
        kills it (kill is treated as success — assertions run on whatever
        output was captured).
      size: sh_test size attr.
      visibility: target visibility.
      tags: target tags. The macro auto-adds `requires-kvm` and `no-cache`.
      **kwargs: forwarded to sh_test.
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
    )

    sh_test(
        name = name,
        srcs = [test_src],
        data = [microvm],
        deps = ["@bazel_tools//tools/bash/runfiles"],
        size = size,
        visibility = visibility,
        # `requires-kvm` lets `--test_tag_filters=-requires-kvm` skip on
        # KVM-less hosts. `no-cache` because boot-time markers are
        # timing-sensitive and shouldn't be cached.
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
        # `init=/sbin/init` makes the kernel call our generated init
        # instead of guessing — some OCI images already ship /sbin/init
        # (e.g. distros with sysvinit) and we want ours to win.
        kernel_cmdline = _DEFAULT_CMDLINE + " init=/sbin/init",
        vcpus = 1,
        mem_mib = 512,
        busybox = _DEFAULT_BUSYBOX,
        visibility = None,
        tags = None,
        **kwargs):
    """Boot a single OCI image inside a firecracker microVM.

    Expands to a runnable `firecracker_microvm` whose rootfs is the
    image's flattened filesystem plus a generated /sbin/init that mounts
    /proc /sys /dev /tmp /run, exports the image Env (plus `extra_env`),
    cd's to WorkingDir, runs Entrypoint+Cmd (plus `extra_args`), then
    poweroffs the VM when the container exits.

    Args:
      name: target name; the runnable microvm sh_binary.
      image: label of an `oci_image` (or any rule emitting an OCI image
        layout directory: index.json + blobs/sha256/...).
      size_mb: rootfs ext4 size in megabytes. Must be larger than the
        flattened image — fail-loud at mkfs time otherwise.
      kernel: label of an uncompressed kernel ELF. Defaults to the
        pinned firecracker vmlinux.
      extra_env: {KEY: VAL} env vars appended to the image's Env. Same-
        named keys override the image's value (later assignment wins).
      extra_args: list of extra args appended after the image's
        Entrypoint+Cmd.
      kernel_cmdline: boot args. Defaults include `init=/sbin/init` so
        the kernel uses our generated init even when the image ships
        its own /sbin/init.
      vcpus: vCPU count.
      mem_mib: guest memory in MiB.
      busybox: statically-linked busybox label; copied to /sbin/busybox
        inside the image and used by /sbin/init for mounts and poweroff.
      visibility: target visibility, forwarded to the microvm.
      tags: target tags, forwarded to the microvm. The macro auto-adds
        `manual` on the intermediate rootfs genrule.
      **kwargs: forwarded to the firecracker_microvm.
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
        # Host mkfs.ext4 + python3 + tar.
        local = True,
        tags = ["manual"],
    )

    firecracker_microvm(
        name = name,
        kernel = kernel,
        rootfs = ":" + rootfs_name,
        kernel_cmdline = kernel_cmdline,
        vcpus = vcpus,
        mem_mib = mem_mib,
        visibility = visibility,
        tags = tags,
        **kwargs
    )
