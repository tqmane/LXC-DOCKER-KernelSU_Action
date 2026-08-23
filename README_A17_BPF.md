# OnePlus 9 Pro Android 17 BPF builds

This repository contains a dedicated workflow for the boot-tested Android 17 BPF backport in `tqmane/android_kernel_oppo_sm8350-private`.

## Plain profile

Workflow: **Build OnePlus 9 Pro Android 17 BPF kernel**

The plain profile:

- syncs `tqmane/android_kernel_manifest` at `oneplus/sm8350v_15.0.0_oneplus9pro`;
- checks out the requested kernel branch, tag, or commit after manifest sync;
- keeps the kernel configuration unmodified;
- does not add Docker, LXC, KVM, KernelSU, or runtime patches;
- preserves the SukiSU source already referenced by the kernel repository;
- verifies BPF, BPF syscall, BPF LSM, and BTF are enabled while function tracing remains disabled;
- publishes the build `dist`, final `.config`, combined OnePlus 9 Pro DTB, `dtbo.img`, AnyKernel3 ZIP, and SHA-256 checksums.

The build uses:

```text
BUILD_CONFIG=kernel/msm-5.4/build.config.lemonade
VARIANT=qgki
LTO=thin
KERNEL_IMAGE_NAME=Image
```

## Required secret

Create an Actions secret named `PRIVATE_REPO_TOKEN`. It must be able to read every private repository referenced by the manifest, including the private kernel and its SukiSU submodule.

## Manual run

Open **Actions → Build OnePlus 9 Pro Android 17 BPF kernel → Run workflow** and provide `kernel_ref`.

The default manual ref is:

```text
oneplus/sm8350v_17.0.0_oneplus9pro_sukisu
```

Pull-request CI for this workflow builds the task-storage hardening branch until that kernel change is merged.
