# OnePlus 9 Pro Android 17 BPF builds

This repository contains a dedicated workflow for the boot-tested Android 17 BPF backport in `tqmane/android_kernel_oppo_sm8350-private`.

Workflow: **Build OnePlus 9 Pro Android 17 BPF kernel**

## Profiles

### `plain`

- syncs `tqmane/android_kernel_manifest` at `oneplus/sm8350v_15.0.0_oneplus9pro`;
- checks out the requested kernel branch, tag, or commit after manifest sync;
- leaves the kernel configuration unmodified;
- does not add Docker, LXC, KVM, KernelSU, or downloaded runtime patches;
- preserves the SukiSU source already referenced by the kernel repository.

### `containers`

Starts from the same Android 17 BPF source and applies a temporary build-time config profile for:

- rootful LXC/Docker namespaces, cgroups, seccomp, pidfd-friendly handles, and POSIX mqueues;
- veth, bridge/netfilter, TUN, macvlan/macvtap, iptables/ip6tables NAT, and conntrack;
- OverlayFS and loop devices;
- arm64 KVM host support plus vhost-net and vhost-vsock.

The profile does **not** add KernelSU, source patches, AUFS, Btrfs patches, or disable Android paranoid networking. It deliberately keeps `CONFIG_FUNCTION_TRACER` disabled to preserve the boot-stable A17 BPF configuration. KVM runtime availability still depends on EL2 and firmware ownership on the physical device.

## Common build settings

```text
BUILD_CONFIG=kernel/msm-5.4/build.config.lemonade
VARIANT=qgki
LTO=thin
KERNEL_IMAGE_NAME=Image
```

Both profiles verify the final BPF/BTF configuration. The containers profile additionally verifies the critical namespace, cgroup, network, OverlayFS, KVM, and vhost symbols in the generated `.config`.

Artifacts include the build `dist`, final `.config`, combined OnePlus 9 Pro DTB, `dtbo.img`, AnyKernel3 ZIP, and SHA-256 checksums. Artifact names include the selected profile.

## Required secret

Create an Actions secret named `PRIVATE_REPO_TOKEN`. It must be able to read every private repository referenced by the manifest, including the private kernel and its SukiSU submodule.

## Manual run

Open **Actions → Build OnePlus 9 Pro Android 17 BPF kernel → Run workflow**, select `plain` or `containers`, and provide `kernel_ref`.

The default manual ref is:

```text
oneplus/sm8350v_17.0.0_oneplus9pro_sukisu
```

Pull-request CI for this workflow builds the task-storage hardening branch until that kernel change is merged.
