# OnePlus 9 Pro Android 17 BPF Kernel Action

OnePlus 9 Pro（SM8350 / GKI 1.0）のAndroid 17向けBPF 5.15部分バックポートを、manifest経由で再現ビルドするGitHub Actionsです。

このリポジトリはカーネルへKernelSUを追加しません。manifestが参照するprivate kernelに既に含まれているSukiSUとsubmoduleを、そのまま同期してビルドします。

## ビルド元

- manifest: `tqmane/android_kernel_manifest`
- manifest branch: `oneplus/sm8350v_15.0.0_oneplus9pro`
- default kernel ref: `oneplus/sm8350v_17.0.0_oneplus9pro_sukisu`
- build config: `kernel/msm-5.4/build.config.lemonade`
- variant: `qgki`
- LTO: `thin`

manifest branch名には15.0.0が残っていますが、`default.xml`のkernel projectはAndroid 17 BPFブランチを参照しています。Workflowの`kernel_ref`入力を使うと、同じmanifest/vendor構成のまま任意のbranch、tag、commitを試せます。

## ビルドプロファイル

GitHub Actionsの`Build OnePlus 9 Pro Android 17 BPF kernel`から、次のどちらかを選びます。

### `plain`

- repo sync後のQGKI configを変更しません。
- Docker、LXC、KVM用configやsource patchを追加しません。
- Android 17 BPF、SukiSU、SuSFSなど、kernel branchに元からある内容だけをビルドします。

### `containers`

plainと同じAndroid 17 BPF sourceに対し、ビルド時だけ次を追加します。

- LXC用namespace、cgroup v1、checkpoint/restore、SysV IPC
- Docker用bridge、NAT、veth、macvlan/ipvlan/vxlan、OverlayFS
- seccomp、pidfd/diagnosticに必要な周辺config
- arm64 KVM、vhost-net
- rootful container向けに`CONFIG_ANDROID_PARANOID_NETWORK`を無効化
- cgroup v1のNOPREFIX互換alias patch

vendor WALT schedulerは維持し、`FAIR_GROUP_SCHED`、`RT_GROUP_SCHED`、`SCHED_AUTOGROUP`を強制しません。AUFSとBtrfsも追加しません。

`miaizhe/Kernel_oplus_sm8350_9RT`のDocker workflowは要件調査の参考にしましたが、別端末の`util.c`、`module.c`、`user.h`をdownloadして丸ごと置換する処理は採用していません。OnePlus 9 ProのsourceとKMIを維持したまま、監査可能なconfig追加と小さなcgroup patchだけを使います。

KVMのkernel supportは有効になりますが、実機での利用可否はEL2、bootloader/firmware、Android userspace側のQEMU構成にも依存します。

## 安全性チェック

ビルド後の最終`.config`を検証し、次を満たさなければWorkflowを失敗させます。

- BPF syscall、JIT、BPF LSM、BTF、CFI、Shadow Call Stackが有効
- `CONFIG_LSM`に`bpf`が存在
- 起動確認されていないarm64 direct trampoline経路を避けるため、`CONFIG_FUNCTION_TRACER`は無効
- `containers`ではnamespace、cgroup、seccomp、veth、OverlayFS、KVM、vhost-netが有効

## Private repository認証

Actions secret `GH_PAT`を登録してください。fine-grained PATには少なくとも次のprivate repositoryへのread権限が必要です。

- `tqmane/android_kernel_oppo_sm8350-private`
- manifest/kernelが参照するprivate SukiSU repository

Tokenはmanifestやartifactへ書き込みません。repo syncとsubmodule syncのcredentialとしてだけ使用します。

## 実行方法

1. Actionsから`Build OnePlus 9 Pro Android 17 BPF kernel`を開きます。
2. `Run workflow`を押します。
3. `profile`で`plain`または`containers`を選びます。
4. 必要なら`kernel_ref`をPR branchやcommit SHAへ変更します。

## 成果物

- Android kernel build frameworkの`dist`
- 最終`kernel.config`
- kernel、manifest、modules、profileを記録した`build-info.txt`
- OnePlus 9 Pro用AnyKernel3 ZIP（Image、連結DTB、dtbo.img）

成果物名には`plain`または`containers`が含まれるため、取り違えを防げます。
