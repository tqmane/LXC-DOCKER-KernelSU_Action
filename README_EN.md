# OnePlus 9 Pro Android 17 BPF Kernel Action

This Action builds the OnePlus 9 Pro Linux 5.4.254 kernel from the Android kernel manifest and build framework. Two selectable profiles are provided:

- `plain`: Android 17 BPF 5.15 compatibility subset plus runtime hardening only
- `containers`: the same fixed kernel with LXC, rootful Docker, and arm64 KVM support

## Sources

- Manifest: `tqmane/android_kernel_manifest`
- Manifest branch: `ci/a17-bpf-runtime-hardening`
- Plain kernel: `fix/a17-bpf-task-storage-hardening`
- Container kernel: `oneplus/sm8350v_17.0.0_oneplus9pro_sukisu_lxc_docker_kvm_v2`

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

The boot-tested Android 17 BPF configuration is kept intact. The Action does not add Docker, LXC, or KVM configuration and does not modify tracked kernel sources.

The resulting configuration is checked for the required BPF/BTF options, disabled function tracing, and the absence of PID namespaces and KVM.

## Container profile

The dedicated kernel branch applies `lahaina_CONTAINER.config` after the normal GKI, QGKI, and vendor fragments. It adds:

- PID, IPC, NET, and UTS namespaces, SysV IPC, and POSIX message queues;
- device, pids, freezer, memory, and CPU-accounting cgroups;
- seccomp filters, file handles, OverlayFS, tmpfs, and devtmpfs;
- veth, bridge netfilter, NAT/iptables, macvlan, ipvlan, vxlan, and tun;
- arm64 KVM, vhost, and vhost-net.

The OPlus WALT scheduler model is retained, so `FAIR_GROUP_SCHED` and `RT_GROUP_SCHED` remain disabled. `USER_NS` also remains disabled.

### GKI 1.0 KABI adaptation and stock-module compatibility

Enabling `SYSVIPC` and `POSIX_MQUEUE` directly can move established fields in `task_struct` and `user_struct`, potentially breaking the KMI or symbol CRCs expected by stock vendor modules. The container branch therefore runs `scripts/gki/apply_container_kabi.py` and relocates the new state into unused Android KABI slots:

- `struct sysv_sem` → `task_struct` slot 3;
- `struct sysv_shm` → `task_struct` slots 4 and 5;
- `mq_bytes` → `user_struct` slot 1.

The Action records the adaptation in a deterministic local commit before building, preventing a `-dirty` suffix in the kernel release. Because the AnyKernel3 package replaces the Image but not stock vendor modules, the container branch also pins `.scmversion` to the plain hardening head suffix. CI accepts this compatibility release only when every matching plain/container `.ko` has identical vermagic and modversion CRC requirements. The effective build commit SHA and the KMI report are included in the artifacts.

The unrelated Reno10 `module.c`, OverlayFS implementation, wholesale `user.h` replacement, and external runtime patches used by the referenced 9RT workflow are deliberately not copied. Only the dedicated SM8350 config and a minimal, reviewable KABI adaptation are used.

## KernelSU / SukiSU

The Action does not clone KernelSU, run a setup script, or inject KSU configuration.

The private kernel tracked by the manifest already contains a SukiSU submodule. It is synced to the exact gitlink pinned by the superproject, with no duplicate installation or override by the Action.

## Private repository authentication

Add a fine-grained PAT with read access to the private kernel and SukiSU repositories using either secret name:

- preferred: `PRIVATE_REPO_TOKEN`
- legacy compatibility: `GH_PAT`

At minimum, access is required for:

- `tqmane/android_kernel_oppo_sm8350-private`
- `tqmane/SukiSU-Ultra-private`

## Running a build

Open `Build OnePlus 9 Pro Android 17 BPF kernel` in GitHub Actions and select either `plain` or `containers` in `Run workflow`.

Pull requests automatically build both profiles, validate the effective configurations, and compare stock-module compatibility.

## Artifacts

Each profile uploads:

- the Android kernel build framework `dist` directory;
- the effective kernel `.config`;
- the exact effective kernel commit SHA;
- a flashable AnyKernel3 ZIP from the manifest-provided `ak3` tree;
- a plain/container module vermagic and modversion CRC comparison report.

DTBs are concatenated in the order used by the boot-tested OnePlus 9 Pro package:

```text
lahaina.dtb -> lahaina-v2.1.dtb -> lahaina-v2.dtb
```

References and build configs are managed in `config.env`. The container profile is compile-tested and checked against the stock module KMI by CI, but device runtime validation should still cover cold boot and Docker, LXC, and KVM separately with a known rollback path available. KVM runtime also depends on the device firmware and hypervisor exposing usable EL2 support.
