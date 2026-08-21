# OnePlus 9 Pro LXC + Docker Kernel Action

This Action builds the Android 15 kernel for the OnePlus 9 Pro **without KernelSU/SukiSU**, while keeping the LXC and Docker configuration and runtime patches.

## Source manifest

- Repository: `tqmane/android_kernel_manifest`
- Branch: `oneplus/sm8350v_15.0.0_oneplus9pro`

The workflow uses `repo init` / `repo sync` and the Android kernel build framework instead of cloning a single kernel repository and calling `make` directly.

```bash
BUILD_CONFIG=kernel/msm-5.4/build.config.lemonade \
VARIANT=qgki \
LTO=thin \
BUILD_KERNEL=1 \
build/build.sh
```

## KernelSU / SukiSU removal

The source manifest currently points to the private kernel branch `oneplus/sm8350v_15.0.0_oneplus9pro_sukisu` and enables its KernelSU submodule.

This Action keeps the rest of the manifest intact and overrides only the kernel project through a local manifest:

- Repository: `tqmane/android_kernel_oppo_sm8350-private`
- Branch: `oneplus/sm8350v_15.0.0_oneplus9pro`

After sync, the workflow verifies that `KernelSU`, `drivers/kernelsu`, and KernelSU/SukiSU submodule configuration are absent. The build is stopped if any of them remain.

## Private repository authentication

Because the kernel source is private, add this Actions secret to the repository:

- Secret name: `PRIVATE_REPO_TOKEN`
- Value: a fine-grained PAT with read access to `tqmane/android_kernel_oppo_sm8350-private`

The token is not written into the workflow source or manifest. It is supplied to Git through the credential helper for `repo sync`.

## LXC / Docker

The default `config.env` keeps LXC and Docker enabled:

```ini
LXC_DOCKER=true
LXC_PATCH=true
ANDROID_PARANOID_NETWORK_OFF=true
```

The LXC/Docker config is applied to the Lahaina QGKI config fragment before `build/build.sh` generates the final defconfig. The cgroup runtime patch and `xt_qtaguid` patch are also retained.

KVM remains optional:

```ini
ENABLE_KVM=false
```

## Running the build

Open GitHub Actions, select `Build OnePlus 9 Pro LXC/Docker kernel`, and choose `Run workflow`.

The workflow uploads:

- the Android kernel build framework `dist` output;
- a OnePlus 9 Pro AnyKernel3 ZIP built from the `ak3` project in the manifest.

The main build settings are in the repository root `config.env`.
