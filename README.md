# OnePlus 9 Pro LXC + Docker Kernel Action

このActionは、指定されたOnePlus 9 Pro用manifestをそのまま同期してビルドしつつ、Action側に元々あったKernelSU導入処理を削除し、LXC / Docker向け設定とパッチだけを追加する構成です。

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

> manifestのREADMEには`build.config.msm.lemonade`とありますが、実際のOnePlus 9/9 Pro kernel treeに存在するファイルは`build.config.lemonade`です。

## KernelSU / SukiSUについて

このAction自身はKernelSUをcloneしたり、`setup.sh`を実行したり、KSU用configを追加したりしません。

ただし、指定manifest自体は現在private kernel branchとKernelSU/SukiSU submoduleを参照しています。そのため、**manifestに元から含まれているKernelSU/SukiSUはそのまま同期されます**。Action側から二重に導入・上書きする処理だけを削除しています。

## Private repository認証

manifestからprivate repositoryとprivate submoduleを同期するため、repositoryのActions secretに次を登録してください。

- Secret name: `PRIVATE_REPO_TOKEN`
- Value: manifestから参照されるprivate repositoryをreadできるfine-grained PAT

現状では少なくとも以下へのread権限が必要です。

- `tqmane/android_kernel_oppo_sm8350-private`
- `tqmane/SukiSU-Ultra-private`

PATはworkflowやmanifestへ直接書き込みません。Git credential helper経由で`repo sync`にだけ使用します。

## LXC / Docker

`config.env`のデフォルトは以下です。

```ini
LXC_DOCKER=true
LXC_PATCH=true
ANDROID_PARANOID_NETWORK_OFF=true
```

LXC / Docker用configはLahaina QGKI fragmentへ追加され、その後`build/build.sh`が最終defconfigを生成します。cgroup runtime patchと`xt_qtaguid` patchも維持しています。

KVMは必要な場合だけ有効化できます。

```ini
ENABLE_KVM=false
```

## 実行方法

GitHub Actionsから `Build OnePlus 9 Pro LXC/Docker kernel` を選び、`Run workflow`を実行してください。

ビルド後は以下をartifactとしてアップロードします。

- Android kernel build frameworkの`dist`出力
- manifestに含まれる`ak3`を使ったOnePlus 9 Pro用AnyKernel3 ZIP

主要な設定はルートの`config.env`にまとめています。
