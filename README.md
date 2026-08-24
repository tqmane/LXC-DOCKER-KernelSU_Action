# OnePlus 9 Pro Android 17 BPF Kernel Action

OnePlus 9 Pro向けLinux 5.4.254カーネルを、Android kernel build frameworkとmanifestからビルドするActionです。実行時に次の2プロファイルを選べます。

- `plain`: Android 17向けBPF 5.15互換サブセット＋runtime hardeningのみ
- `containers`: 同じ修正版を基準にLXC、rootful Docker、arm64 KVMを追加

## ビルド元

- manifest: `tqmane/android_kernel_manifest`
- manifest branch: `ci/a17-bpf-runtime-hardening`
- plain kernel: `fix/a17-bpf-task-storage-hardening`
- container kernel: `oneplus/sm8350v_17.0.0_oneplus9pro_sukisu_lxc_docker_kvm_v2`

共通ビルド条件は次のとおりです。

```bash
VARIANT=qgki
LTO=thin
BUILD_KERNEL=1
```

`plain`は次を使用します。

```bash
BUILD_CONFIG=kernel/msm-5.4/build.config.lemonade build/build.sh
```

`containers`は次を使用します。

```bash
BUILD_CONFIG=kernel/msm-5.4/build.config.lemonade.container build/build.sh
```

## plainプロファイル

起動確認済みのAndroid 17 BPF構成を保ちます。ActionはDocker、LXC、KVM向けconfigを追加せず、追跡対象のカーネルソースも変更しません。

ビルド後、少なくとも次を検証します。

- `CONFIG_BPF_SYSCALL=y`
- `CONFIG_BPF_JIT=y`
- `CONFIG_BPF_JIT_ALWAYS_ON=y`
- `CONFIG_BPF_LSM=y`
- `CONFIG_DEBUG_INFO_BTF=y`
- `CONFIG_FUNCTION_TRACER=n`
- `CONFIG_PID_NS=n`
- `CONFIG_KVM=n`

## containersプロファイル

専用ブランチの`lahaina_CONTAINER.config`を通常のQGKI/vendor fragmentの最後に適用します。主な追加項目は次のとおりです。

- PID／IPC／NET／UTS namespace、SysV IPC、POSIX message queue
- device、pids、freezer、memory、CPU accountingなどのcgroup
- seccomp filter、file handles、OverlayFS、tmpfs、devtmpfs
- veth、bridge netfilter、NAT／iptables、macvlan、ipvlan、vxlan、tun
- arm64 KVM、vhost、vhost-net

OPlusのWALT schedulerを維持するため、`FAIR_GROUP_SCHED`と`RT_GROUP_SCHED`は有効化しません。`USER_NS`も無効のままです。

### GKI 1.0 KABI適応とstock module互換

`SYSVIPC`と`POSIX_MQUEUE`を単純に有効化すると、`task_struct`と`user_struct`の既存field位置が変わり、stock vendor moduleのKMI／CRCを壊す可能性があります。そのため、container branch内の`scripts/gki/apply_container_kabi.py`を実行し、追加stateを未使用のAndroid KABI slotへ移します。

- `struct sysv_sem` → `task_struct` slot 3
- `struct sysv_shm` → `task_struct` slots 4／5
- `mq_bytes` → `user_struct` slot 1

Actionは適応後の差分を固定日時のlocal commitにしてからビルドするため、kernel releaseへ`-dirty`を付けません。container branchの`.scmversion`はplain hardening headのSCM suffixへ固定し、Imageだけを入れ替えるAnyKernel3でもstock moduleと同じvermagicを維持します。この固定は、CIでplain／containerの同名`.ko`についてvermagicと全modversion CRCが一致した場合だけ合格とします。成果物には実際にビルドしたcommit SHAとKMI比較レポートも保存します。

9RT参考repoにあった別機種Reno10用`module.c`、OverlayFS実装、`user.h`の丸ごと置換、外部runtime patchは使用していません。SM8350ツリー内の専用configと、レビュー可能な最小KABI適応だけを使用します。

## KernelSU／SukiSU

このAction自身はKernelSUをcloneせず、`setup.sh`を実行せず、KSU configも注入しません。

manifestが追跡するprivate kernelには既にSukiSU submoduleが含まれるため、それをsuperprojectの固定gitlinkへ同期します。Action側から二重導入や上書きは行いません。

## Private repository認証

次のいずれかのActions secretへ、private kernelとSukiSU submoduleをreadできるfine-grained PATを登録してください。

- 推奨: `PRIVATE_REPO_TOKEN`
- 互換: `GH_PAT`

少なくとも次へのread権限が必要です。

- `tqmane/android_kernel_oppo_sm8350-private`
- `tqmane/SukiSU-Ultra-private`

## 実行方法

GitHub Actionsで`Build OnePlus 9 Pro Android 17 BPF kernel`を開き、`Run workflow`から次のどちらかを選びます。

```text
plain
containers
```

Pull Requestでは両プロファイルが自動でビルドされ、最終`.config`とstock module互換性も検査されます。

## 成果物

各プロファイルについて次をアップロードします。

- Android kernel build frameworkの`dist`一式
- 実際に使用した`effective.config`
- 実際にビルドしたkernel commit SHA
- manifestのAnyKernel3を使用したflashable ZIP
- plain／container間のmodule vermagic・modversion CRC比較レポート

DTBは、実機起動確認済みpackageに合わせて次の順で連結します。

```text
lahaina.dtb -> lahaina-v2.1.dtb -> lahaina-v2.dtb
```

主要なrefとbuild configは`config.env`で管理しています。containerプロファイルはCIでbuild可能性とstock module互換性を検証しますが、実機導入前には必ずrollback手段を確保し、cold boot、Docker/LXC/KVMのruntimeを個別に確認してください。KVMの実行には端末firmware／hypervisorがEL2を利用可能にしていることも必要です。
