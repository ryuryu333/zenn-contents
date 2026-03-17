---
title: "1.4 Nix のインストール"
---

# 1. この章でやること
この章では Nix のインストールを行います。


# 2. インストール手順
NixOS コミュニティーで管理されているインストーラーを利用します。

https://github.com/NixOS/nix-installer

以下を実行します。

```bash:Bash
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install
```

インストーラーがシステムに合わせて Nix インストールの Plan が作成されます。
実行してよいか聞かれるので `y` を入力してください。

:::message
**WSL2、macOS、Linux などが対応しています**。
Windows の場合、WSL 環境内でのみ Nix を利用できます。ホスト側の管理は Nix で出来ません。
:::

:::message
**このインストーラーを利用すると、Flakes 有効化などの設定を自動で行ってくれます**。
**また、アンインストール機能も付いており便利です**。

----

本書では Flakes という Nix の実験的機能（experimental features）を利用する前提で解説します。

>「実験的機能」と名前が厳ついですが、Flakes は事実上のデファクトスタンダードな機能ですので、有効化しても支障ありません。
:::


# 3. インストール確認
インストーラーから指示されたコマンドを実行します。

```bash:Bash
`. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`
```

Nix コマンドが利用可能か以下で確認します。

```bash:Bash
nix --version
```

バージョンが表示されればインストール完了です。

```bash:実行例
$ nix --version
nix (Nix) 2.33.3
```


# 4. 補足
## 4.1 アンインストール

```bash:Bash
/nix/nix-installer uninstall
```


## 4.2 更新

```bash:Bash
sudo -i nix upgrade-nix
```


## 4.3 インストーラーの種類・違い
本章で紹介した以外のインストーラーに興味がある方は、以下の記事を参照してください。
主要なインストーラー 4 種について解説・比較検証しています。

https://zenn.dev/trifolium/articles/da11a428c53f65
