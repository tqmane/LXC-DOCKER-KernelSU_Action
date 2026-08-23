# OnePlus 9 Pro Android 17 BPF Kernel Action

This Action builds the OnePlus 9 Pro Linux 5.4.254 kernel from the Android kernel manifest and build framework. Two selectable profiles are provided:

- `plain`: Android 17 BPF 5.15 compatibility subset plus runtime hardening only
- `containers`: the same fixed kernel with LXC, rootful Docker, and arm64 KVM support

## Sources

- Manifest: `tqmane/android_kernel_manifest`
- Manifest branch: `ci/a17-bpf-runtime-hardening`
- Plain kernel: `fix/android17-bpf-task-storage-recursion`
- Container kernel: `oneplus/sm8350v_17.0.0_oneplus9pro_sukisu_lxc_docker_kvm`

Both profiles use:

```bash
VARIANT=qgki
LTO=thin
BUILD_KERNEL=1
```

The plain build uses:

```bash
BUILD_CONFIG=kernel/msm-5.4/build.config.lemonade build/build.sh
```

The container build uses:

```bash
BUILD_CONFIG=kernel/msm-5.4/build.config.lemonade.container build/build.sh
```

## Plain profile

The boot-tested Android 17 BPF configuration is kept intact. The Action does not add Docker, LXC, or KVM configuration and does not patch kernel sources at build time.

The resulting configuration is checked for the required BPF/BTF options, disabled function tracing, and the absence of PID namespaces and KVM.

## Container profile

The dedicated kernel branch applies `lahaina_CONTAINER.config` after the normal GKI, QGKI, and vendor fragments. It adds:

- PID, IPC, NET, and UTS namespaces, SysV IPC, and POSIX message queues;
- device, pids, freezer, memory, and CPU-accounting cgroups;
- seccomp filters, file handles, OverlayFS, tmpfs, and devtmpfs;
- veth, bridge netfilter, NAT/iptables, macvlan, ipvlan, vxlan, and tun;
- arm64 KVM, vhost, and vhost-net.

The OPlus WALT scheduler model is retained, so `FAIR_GROUP_SCHED` and `RT_GROUP_SCHED` remain disabled. `USER_NS` also remains disabled.

The unrelated Reno10 `module.c`, OverlayFS implementation, `user.h`, and external runtime patches used by the referenced 9RT workflow are deliberately not copied. The SM8350 source remains intact and the feature set is enabled through a dedicated config profile.

## KernelSU / SukiSU

The Action does not clone KernelSU, run a setup script, or inject KSU configuration.

The private kernel tracked by the manifest already contains a SukiSU submodule, which is synced as a normal source dependency. No duplicate installation or override is performed by the Action.

## Private repository authentication

Add a fine-grained PAT with read access to the private kernel and SukiSU repositories using either secret name:

- preferred: `PRIVATE_REPO_TOKEN`
- legacy compatibility: `GH_PAT`

At minimum, access is required for:

- `tqmane/android_kernel_oppo_sm8350-private`
- `tqmane/SukiSU-Ultra-private`

## Running a build

Open `Build OnePlus 9 Pro Android 17 BPF kernel` in GitHub Actions and select either `plain` or `containers` in `Run workflow`.

Pull requests automatically build and validate both profiles.

## Artifacts

Each profile uploads:

- the Android kernel build framework `dist` directory;
- the effective kernel `.config`;
- a flashable AnyKernel3 ZIP from the manifest-provided `ak3` tree.

DTBs are concatenated in the order used by the boot-tested OnePlus 9 Pro package:

```text
lahaina.dtb -> lahaina-v2.1.dtb -> lahaina-v2.dtb
```

References and build configs are managed in `config.env`. The container profile is compile-tested by CI, but device runtime validation should still cover cold boot and Docker, LXC, and KVM separately with a known rollback path available.
