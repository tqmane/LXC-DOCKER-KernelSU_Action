# OnePlus 9 Pro Android 17 BPF Kernel Action

This repository reproducibly builds the Android 17 BPF 5.15 compatibility backport for the OnePlus 9 Pro (SM8350 / GKI 1.0) through the Android kernel manifest and build framework.

The Action does not install KernelSU. It keeps the SukiSU source and submodule already referenced by the private kernel manifest and builds them without running another setup script.

## Sources

- manifest: `tqmane/android_kernel_manifest`
- manifest branch: `oneplus/sm8350v_15.0.0_oneplus9pro`
- default kernel ref: `oneplus/sm8350v_17.0.0_oneplus9pro_sukisu`
- build config: `kernel/msm-5.4/build.config.lemonade`
- variant: `qgki`
- LTO: `thin`

The manifest branch name still contains 15.0.0, but its kernel project points to the Android 17 BPF branch. The `kernel_ref` workflow input can select another branch, tag, or commit while keeping the same manifest and vendor tree.

## Build profiles

Run `Build OnePlus 9 Pro Android 17 BPF kernel` from GitHub Actions and choose one profile.

### `plain`

- Leaves the synced QGKI config unchanged.
- Adds no Docker, LXC, or KVM options and applies no source patch.
- Builds only what is already present in the selected Android 17 BPF/SukiSU kernel ref.

### `containers`

Extends the same Android 17 BPF source at build time with:

- LXC namespaces, cgroup v1, checkpoint/restore, and SysV IPC
- Docker bridge/NAT/veth/macvlan/ipvlan/vxlan and OverlayFS support
- seccomp and supporting diagnostic options
- arm64 KVM and vhost-net
- disabled `CONFIG_ANDROID_PARANOID_NETWORK` for rootful containers
- a small cgroup v1 NOPREFIX compatibility-alias patch

The vendor WALT scheduler is preserved. The profile does not force `FAIR_GROUP_SCHED`, `RT_GROUP_SCHED`, or `SCHED_AUTOGROUP`, and it does not add AUFS or Btrfs.

The Docker workflow in `miaizhe/Kernel_oplus_sm8350_9RT` was reviewed for requirements, but this implementation deliberately does not download and replace `util.c`, `module.c`, or `user.h` from an unrelated device. It keeps the OnePlus 9 Pro source and KMI intact and uses only auditable config additions plus the local cgroup patch.

Kernel-side KVM support is enabled, but runtime availability still depends on EL2, the bootloader/firmware, and the Android userspace QEMU setup.

## Configuration validation

After each build, the generated `.config` is checked. The workflow fails unless:

- BPF syscall, JIT, BPF LSM, BTF, CFI, and Shadow Call Stack are enabled
- `CONFIG_LSM` contains `bpf`
- `CONFIG_FUNCTION_TRACER` remains disabled to avoid the unverified arm64 direct-trampoline path
- the `containers` profile contains the required namespace, cgroup, seccomp, veth, OverlayFS, KVM, and vhost-net options

## Private repository authentication

Create an Actions secret named `GH_PAT`. Its fine-grained token needs read access to at least:

- `tqmane/android_kernel_oppo_sm8350-private`
- the private SukiSU repository referenced by the manifest/kernel

The token is used only as a repo/submodule sync credential and is not written to the manifest or artifacts.

## Running a build

1. Open `Build OnePlus 9 Pro Android 17 BPF kernel` in Actions.
2. Select `Run workflow`.
3. Choose `plain` or `containers`.
4. Optionally replace `kernel_ref` with a pull-request branch or commit SHA.

## Artifacts

- Android kernel build-framework `dist`
- final `kernel.config`
- `build-info.txt` recording the profile and kernel/manifest/modules revisions
- OnePlus 9 Pro AnyKernel3 ZIP containing Image, combined DTB, and dtbo.img

Artifact names include `plain` or `containers` to prevent accidental mix-ups.
