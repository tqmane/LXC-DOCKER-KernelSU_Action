# OnePlus 9 Pro Android 17 BPF Kernel Action

This Action builds the OnePlus 9 Pro Linux 5.4.254 kernel with the Android kernel manifest and build framework. Two profiles are available:

- `plain`: the normal Android 17 BPF/SukiSU kernel;
- `containers`: the same source with LXC, rootful Docker, and arm64 KVM configuration.

## Sources

- Manifest: `tqmane/android_kernel_manifest`
- Manifest branch: `ci/a17-bpf-runtime-hardening`
- Kernel: `oneplus/sm8350v_17.0.0_oneplus9pro_sukisu`

Both profiles use the same kernel branch. Only `BUILD_CONFIG` changes:

```text
plain      -> kernel/msm-5.4/build.config.lemonade
containers -> kernel/msm-5.4/build.config.lemonade.container
```

Common settings:

```text
VARIANT=qgki
LTO=thin
BUILD_KERNEL=1
```

The optional `kernel_ref` input may be used to validate an in-flight kernel PR. When omitted, the current production branch above is always used.

## Plain profile

The normal device build configuration is preserved. The workflow no longer assumes that `PID_NS` or `KVM` must be disabled merely because the profile is named plain; that incorrect assertion previously rejected a successfully compiled kernel.

Both profiles validate:

- `CONFIG_BPF_SYSCALL=y`;
- `CONFIG_BPF_JIT=y`;
- `CONFIG_BPF_JIT_ALWAYS_ON=y`;
- `CONFIG_BPF_LSM=y`;
- `CONFIG_DEBUG_INFO_BTF=y`;
- `CONFIG_LSM` contains `bpf`;
- `CONFIG_FUNCTION_TRACER` is disabled;
- `.BTF` and `.BTF_ids` exist in `vmlinux`;
- the `.BTF_ids` address and ELF alignment are at least four-byte aligned.

## Container profile

`lahaina_CONTAINER.config` is applied after the normal GKI, QGKI, and vendor fragments. It adds:

- PID, IPC, NET, and UTS namespaces, SysV IPC, and POSIX message queues;
- device, pids, freezer, memory, and CPU-accounting cgroups;
- seccomp filters, file handles, OverlayFS, tmpfs, and devtmpfs;
- veth, bridge netfilter, NAT/iptables, macvlan, ipvlan, vxlan, and tun;
- arm64 KVM, vhost, and vhost-net.

The OPlus WALT scheduler model is retained, so `FAIR_GROUP_SCHED` and `RT_GROUP_SCHED` remain disabled. `USER_NS` also remains disabled.

### GKI 1.0 KABI adaptation

To avoid moving established `task_struct` and `user_struct` fields when `SYSVIPC` and `POSIX_MQUEUE` are enabled, the workflow runs the source-owned `scripts/gki/apply_container_kabi.py` adaptation:

- `struct sysv_sem` → `task_struct` slot 3;
- `struct sysv_shm` → `task_struct` slots 4 and 5;
- `mq_bytes` → `user_struct` slot 1.

The resulting change is recorded in a deterministic local commit before the build, preventing a `-dirty` kernel release suffix.

The unrelated Reno10 `module.c`, OverlayFS implementation, wholesale `user.h` replacement, and external runtime patches from the referenced 9RT workflow are not copied.

## SukiSU

The Action does not clone KernelSU, run an installation script, or inject KSU configuration. It synchronizes the SukiSU submodule already pinned by the kernel superproject.

## Private repository authentication

Add a fine-grained PAT with read access to the private kernel and SukiSU repositories as an Actions secret:

- preferred: `PRIVATE_REPO_TOKEN`;
- compatible legacy names: `GH_PAT` or `PAT`.

## Running a build

Open `Build OnePlus 9 Pro Android 17 BPF kernel` in Actions and choose:

```text
plain
containers
```

Normally, leave `kernel_ref` empty.

Pull requests perform full builds for both profiles and validate the effective configuration, BTF sections, and artifact generation. When matching `.ko` files exist in both dist artifacts, their vermagic and modversion CRC requirements are compared. If the dist contains no comparable module set, the report explicitly records that KMI validation was skipped and emits a warning instead of failing an otherwise valid kernel build.

## Artifacts

- Android kernel build framework `dist`;
- effective `.config`;
- complete build log;
- `readelf` section listing;
- source/effective commit SHAs and build metadata;
- flashable AnyKernel3 ZIP;
- SHA-256 checksums;
- module KMI report.

DTBs are concatenated in the order used by the existing package:

```text
lahaina -> v2.1 -> v2
```

A successful CI build does not replace device validation. Test cold boot, Docker, LXC, networking, stock modules, SukiSU, and KVM separately with a rollback path available. KVM runtime also requires firmware or hypervisor support that exposes usable EL2.
