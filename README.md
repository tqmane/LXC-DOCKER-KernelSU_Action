# OnePlus 9 Pro LXC + Docker Kernel Action

このActionは、OnePlus 9 Pro向けAndroid 15 kernelを **KernelSU/SukiSUなし** でビルドし、LXC / Docker向け設定とパッチを残す構成です。

## ビルド元

manifest:

- `tqmane/android_kernel_manifest`
- branch: `oneplus/sm8350v_15.0.0_oneplus9pro`

ビルドは単一kernel repositoryを直接`make`する方式ではなく、manifestを`repo init` / `repo sync`した後、Android kernel build frameworkを使います。

```bash
BUILD_CONFIG=kernel/msm-5.4/build.config.lemonade \
VARIANT=qgki \
LTO=thin \
BUILD_KERNEL=1 \
build/build.sh
```

## KernelSU / SukiSUについて

指定manifestは現在、private kernel repositoryの`oneplus/sm8350v_15.0.0_oneplus9pro_sukisu`とKernelSU submoduleを参照しています。

このActionではmanifestの他のproject構成はそのまま使用し、kernel projectだけを以下へlocal manifestでoverrideします。

- repository: `tqmane/android_kernel_oppo_sm8350-private`
- branch: `oneplus/sm8350v_15.0.0_oneplus9pro`

同期後に`KernelSU`、`drivers/kernelsu`、KernelSU/SukiSU submoduleが存在しないことも確認し、残っている場合はビルドを停止します。

## Private repository認証

kernel sourceがprivate repositoryなので、repositoryのActions secretに次を登録してください。

- Secret name: `PRIVATE_REPO_TOKEN`
- Value: `tqmane/android_kernel_oppo_sm8350-private`をreadできるfine-grained PAT

PATはworkflowやmanifestへ直接書き込みません。Git credential helper経由で`repo sync`にだけ使用します。

## LXC / Docker

`config.env`のデフォルトは以下です。

```ini
LXC_DOCKER=true
LXC_PATCH=true
ANDROID_PARANOID_NETWORK_OFF=true
```

LXC / Docker用configはQGKI fragmentへ追加され、その後`build/build.sh`が最終defconfigを生成します。cgroup runtime patchと`xt_qtaguid` patchも維持しています。

KVMは必要な場合のみ有効化できます。

```ini
ENABLE_KVM=false
```

## 実行方法

GitHub Actionsから `Build OnePlus 9 Pro LXC/Docker kernel` を選び、`Run workflow`を実行してください。

ビルド後は以下をartifactとしてアップロードします。

- Android kernel build frameworkの`dist`出力
- manifestに含まれる`ak3`を使ったOnePlus 9 Pro用AnyKernel3 ZIP

主要な設定はルートの`config.env`にまとめています。
