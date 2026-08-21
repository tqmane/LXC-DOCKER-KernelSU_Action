# OnePlus 9 Pro LXC + Docker Kernel Action

This Action syncs and builds the supplied OnePlus 9 Pro manifest as-is, removes the old KernelSU installation logic from the Action itself, and keeps the LXC/Docker configuration and runtime patches.

## Source manifest

- Repository: `tqmane/android_kernel_manifest`
- Branch: `oneplus/sm8350v_15.0.0_oneplus9pro`

The workflow uses `repo init` / `repo sync` and the Android kernel build framework instead of cloning a single kernel repository and invoking `make` directly.

```bash
BUILD_CONFIG=kernel/msm-5.4/build.config.lemonade \
VARIANT=qgki \
LTO=thin \
BUILD_KERNEL=1 \
build/build.sh
```

> The manifest README currently refers to `build.config.msm.lemonade`, but the actual OnePlus 9/9 Pro kernel tree contains `build.config.lemonade`.

## KernelSU / SukiSU behavior

This Action no longer clones KernelSU, runs a KernelSU `setup.sh`, or injects KSU-specific configuration.

The supplied manifest itself currently references a private kernel branch and a KernelSU/SukiSU submodule. Therefore, **KernelSU/SukiSU that already belongs to the manifest is still synced exactly as specified by that manifest**. Only the Action-level duplicate installation/override logic has been removed.

## Private repository authentication

The manifest references private repositories and a private submodule. Add the following Actions secret to this repository:

- Secret name: `PRIVATE_REPO_TOKEN`
- Value: a fine-grained PAT with read access to every private repository referenced by the manifest

At minimum, the current manifest requires read access to:

- `tqmane/android_kernel_oppo_sm8350-private`
- `tqmane/SukiSU-Ultra-private`

The PAT is not embedded in the workflow or manifest. It is provided to Git through the credential helper for `repo sync`.

## LXC / Docker

The default `config.env` keeps LXC and Docker enabled:

```ini
LXC_DOCKER=true
LXC_PATCH=true
ANDROID_PARANOID_NETWORK_OFF=true
```

The LXC/Docker configuration is applied to the Lahaina QGKI fragment before `build/build.sh` generates the final defconfig. The cgroup runtime patch and `xt_qtaguid` patch are also retained.

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
