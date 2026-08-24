# OnePlus 9 Pro Android 17 BPF Kernel Action

OnePlus 9 Pro向けLinux 5.4.254カーネルを、Android kernel build frameworkとmanifestからビルドするActionです。実行時に2つのprofileを選べます。

- `plain`: 通常のAndroid 17 BPF／SukiSUカーネル
- `containers`: 同じsourceへLXC、rootful Docker、arm64 KVM用configを追加

## ビルド元

- manifest: `tqmane/android_kernel_manifest`
- manifest branch: `ci/a17-bpf-runtime-hardening`
- kernel: `oneplus/sm8350v_17.0.0_oneplus9pro_sukisu`

plainとcontainersでkernel branchを分けません。違うのは`BUILD_CONFIG`だけです。

```text
plain      -> kernel/msm-5.4/build.config.lemonade
containers -> kernel/msm-5.4/build.config.lemonade.container
```

共通条件:

```text
VARIANT=qgki
LTO=thin
BUILD_KERNEL=1
```

kernel PRを検証するときだけ、手動入力またはreusable workflowの`kernel_ref`で一時branch／commitを指定できます。未指定時は常に上記の本流を使用します。

## plain profile

端末用の通常build configをそのまま使用します。plainだからといって`PID_NS`や`KVM`が必ず無効とは仮定しません。以前のCIはこの誤った仮定により、正常にコンパイル済みのplain buildを失敗扱いしていました。

両profileで次を確認します。

- `CONFIG_BPF_SYSCALL=y`
- `CONFIG_BPF_JIT=y`
- `CONFIG_BPF_JIT_ALWAYS_ON=y`
- `CONFIG_BPF_LSM=y`
- `CONFIG_DEBUG_INFO_BTF=y`
- `CONFIG_LSM`に`bpf`を含む
- `CONFIG_FUNCTION_TRACER`は無効
- `vmlinux`に`.BTF`と`.BTF_ids`が存在
- `.BTF_ids`のaddressとELF alignmentが4-byte以上

## containers profile

`lahaina_CONTAINER.config`を通常のQGKI/vendor fragmentの最後に適用します。主な追加項目:

- PID／IPC／NET／UTS namespace、SysV IPC、POSIX message queue
- device、pids、freezer、memory、CPU accountingなどのcgroup
- seccomp filter、file handles、OverlayFS、tmpfs、devtmpfs
- veth、bridge netfilter、NAT／iptables、macvlan、ipvlan、vxlan、tun
- arm64 KVM、vhost、vhost-net

OPlusのWALT schedulerを維持するため、`FAIR_GROUP_SCHED`と`RT_GROUP_SCHED`は無効のままです。`USER_NS`も無効です。

### GKI 1.0 KABI適応

`SYSVIPC`と`POSIX_MQUEUE`で`task_struct`／`user_struct`の既存fieldを動かさないよう、source内の`scripts/gki/apply_container_kabi.py`を実行します。

- `struct sysv_sem` → `task_struct` slot 3
- `struct sysv_shm` → `task_struct` slots 4／5
- `mq_bytes` → `user_struct` slot 1

差分は固定日時のlocal commitにしてからビルドするため、kernel releaseへ`-dirty`を付けません。

9RT参考repoにある別機種Reno10用`module.c`、OverlayFS実装、`user.h`丸ごと置換、外部runtime patchは使用しません。

## SukiSU

Action側ではKernelSUをcloneせず、setup scriptもKSU config注入も行いません。kernel sourceに含まれるSukiSU submoduleをsuperproject指定のcommitへ同期します。

## Private repository認証

private kernelとSukiSUをreadできるfine-grained PATをActions secretへ登録してください。

- 推奨: `PRIVATE_REPO_TOKEN`
- 互換: `GH_PAT`または`PAT`

## 実行方法

Actionsの`Build OnePlus 9 Pro Android 17 BPF kernel`から、次を選択します。

```text
plain
containers
```

通常は`kernel_ref`を空欄のままにします。

Pull Requestでは両profileをfull buildし、最終config、BTF section、成果物生成を検査します。同一pathの`.ko`が両distにある場合はvermagicとmodversion CRCも比較します。distに比較可能なmoduleがない場合は、KMI検査を「未実施」と明記してwarningにし、カーネルbuild自体を失敗扱いにはしません。

## 成果物

- Android kernel build frameworkの`dist`
- `effective.config`
- build log
- `readelf` section一覧
- source／effective commit SHAとbuild metadata
- AnyKernel3 ZIP
- SHA-256一覧
- module KMI比較レポート

DTBは既存packageと同じ順で連結します。

```text
lahaina -> v2.1 -> v2
```

container buildがCIで成功しても、実機ではcold boot、Docker、LXC、network、stock module、SukiSU、KVMを個別に確認してください。KVM runtimeにはfirmware／hypervisorがEL2を利用可能にしている必要があります。
